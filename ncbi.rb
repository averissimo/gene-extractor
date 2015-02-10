require 'net/http'
require 'json'
require 'logger'
require 'rexml/document'
require 'bio'

class NcbiAPI

  TRANSLATION_PREFIX = "ncbi"

  SEARCH_DB = "nuccore"
  PROTEIN_DB  = "protein"
  DOWNLOAD_DB = "nuccore"

  NUM_THREADS = 15

  SEARCH = "search"
  GENBANK = "GenBank"
  NA = "na"

  def log() @logger end

  #
  #
  #
  def initialize( email, response=nil, type=nil, keyword=nil )
    @ncbi = Bio::NCBI::REST.new
    @email = email
    Bio::NCBI.default_email = @email

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    log.debug "creating a new NCBIAPI object..." if response.nil?

    @response = response
    @type = type
    @keyword = keyword
  end

  def response
    @response
  end

  def find term, field=[]
    field = [field] if field.class == String
    search_ary = field.collect do |el|
      "(\"#{term}\"[#{el}])"
    end
    search_term = "(" + search_ary.join(" OR ") + ")" + " AND \"cds\"[Feature key]"
    #
    @response = @ncbi.esearch search_term, { "db" => SEARCH_DB }, 0
    @type = SEARCH
    @keyword = search_term
    log.info " -> #{@response.size} results"
    self
  end

  def ntseq
    if @type == NA
      @response
    else
      nil
    end
  end

  def aaseq
    if @type == NA
      Bio::Sequenece::NA.new(@response).translate
    else
        nil
    end
  end

  def download_genes()
    # checks if it is a search is stored here
    if @type != SEARCH
      log.error(msg = "error: a search result is not stored in this object.")
      raise msg
    end

    gene_queue = Queue.new
    threads = []
    @response.each { |el| gene_queue << el }

    # multi-thread!!
    NUM_THREADS.times.each do
      threads << Thread.new do
        result = []
        until gene_queue.size == 0
          el = gene_queue.pop
          result << download_cds(el)
        end
        result
      end
    end
    log.info "-- joinning"
    result = threads.collect do |thr|
      thr.value
    end
    # returns an array of genes (i.e. NCBI objects)
    result.flatten
  end

  def download_cds(el)
    # get the GenBank data for the protein (that should have a CDS)
    ntseq = @ncbi.efetch el, { "db"=>DOWNLOAD_DB, "rettype"=>"fasta_cds_na" }
    # add el to start of the query
    ntseq = ntseq.gsub /^([\>])/, ">#{el} "
    # get the protein name from query
    begin
      definition = ntseq.match(/\[protein=([^\]]+)/)[1]
    rescue # if cannot determine protein, then show the default msg
      definition = "(could not get protein from cds result)"
    end

    log.info "  Definition (#{el}): #{definition}"
    obj = NcbiAPI.new @email, ntseq, NA, el
    obj
  end

  def definition
    @response.definition.gsub /[\[](\w|\s)+[\]]/, ""
  end

  def organism
    @response.common_name
  end


  def download(keyword)
    protein = Bio::GenBank.new(@ncbi.efetch keyword, {"db"=>PROTEIN_DB, "rettype"=>"gb"})
    NcbiAPI.new(@email, protein, GENBANK, keyword)
  end

  def self.translate(email)
    translation = Hash.new
    ncbi = NcbiAPI.new(email)
    File.open "translate-ncbi.out.txt", 'w' do |fw|
      File.open "translate.txt", 'r' do |f|
        keys = f.read.split( /\n/ )
        keys.each do |el|
          # take only kegg lines
          next unless el.start_with?(TRANSLATION_PREFIX)
          # replace prefix with void
          el = el.gsub Regexp.new("^" + TRANSLATION_PREFIX + " "), ""
          resp = ncbi.download(el)
          translation[el] = {}
          translation[el][:definition] = resp.definition
          translation[el][:organism]   = resp.organism
          fw.puts [el, translation[el][:definition], translation[el][:organism]].join("\t")
        end
      end
    end
    translation
  end

end
