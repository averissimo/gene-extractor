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

    list = @response.collect do |el|
      # get the GenBank data for the protein (that should have a CDS)
      ntseq = @ncbi.efetch el, { "db"=>DOWNLOAD_DB, "rettype"=>"fasta_cds_na" }
      metadata = Bio::GenBank.new( @ncbi.efetch el, { "db"=>DOWNLOAD_DB, "rettype"=>"gb" })
      ntseq.gsub /^([>])/, "\1#{el} "
      log.info "  Definition (#{el}): #{metadata.definition}"
      obj = NcbiAPI.new @email, ntseq, NA, el
      obj
    end

    # returns an array of genes (i.e. NCBI objects)
    list
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

  def self.translate
    translation = Hash.new
    ncbi = NcbiAPI.new
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
