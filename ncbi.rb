require 'net/http'
require 'json'
require 'logger'
require 'rexml/document'
require 'byebug'

class NCBIAPI

  BASE_PATH = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

  DOWNLOAD_PREFIX = "efetch.fcgi?"
  SEARCH_PREFIX = "esearch.fcgi?&retmax=200&"
  SUMMARY_PREFIX ="esummary.fcgi?"

  TRANSLATION_PREFIX = "ncbi"

  SEARCH_DB = "gene"
  FASTA_DB  = "nuccore"

  def log() @logger end

  #
  #
  #
  def initialize( response=nil )
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    log.debug "creating a new NCBIAPI object..." if response.nil?

    @response = response
  end

  def response() @response end
  def ntseq() @ntseq end

  def summaries(id_list, retstart=0)
    summary_url = build_summary_url( id_list, "", "json" )
    response = api( summary_url )
    unless response["result"].nil?
      uids = response["result"]["uids"]
      response["result"].delete "uids"
    end
    response["result"]
  end

  #
  #
  # gets 'genomicinfo' array and outputs list of genome info
  def get_genome_info(list, uid)
    list.collect do |el|
      g_start = el["chrstart"] + 1
      g_end   = el["chrstop"] + 1
      if g_start > g_end
        g_aux   = g_start
        g_start = g_end
        g_end   = g_aux
      end
      result= { uid: uid, accver: el["chraccver"], start: g_start, end: g_end, loc: el["chrloc"], exon: el["exoncount"] }
      log.debug "adding #{result[:uid]} with accver = '#{result[:accver]}' that starts at #{result[:start]} and ends #{result[:end]}"
      result
    end
  end

  #
  #
  # download many genes
  def download_genes()
    raise "this object has no data (i.e. no summaries)" if @response.nil?
    summaries = @response
    download_gene(summaries)
  end

  #
  #
  # used to donwload one gene at a time.
  # it is useful to add uid annotation each query
  def download_next_gene()
    if @response.nil?
      log.warn "this object has no data (i.e. no summaries)"
      @ntseq = nil
      return nil
    end
    pop_summ = @response.shift

    return nil if pop_summ.nil?

    summaries = Hash.new
    key = pop_summ[0]
    val = pop_summ[1]
    summaries[key] = val
    download_gene(summaries)
    @ntseq = @ntseq.gsub /^([>])/, "\\1#{val["uid"]} "
  end

  #
  #
  # download an individual gene fasta file(s)
  def download_gene(summaries)

    list = []
    # iterate all individual summaries and get genome info
    summaries.values.each do |sum|
      # get genome information, either genomicinfo or locationhist
      fasta_loc = if sum.has_key?("genomicinfo") && sum["genomicinfo"].size > 0
        sum["genomicinfo"]
      elsif sum.has_key?("locationhist") && sum["locationhist"].size > 0
        sum["locationhist"]
      else
        []
      end
      #
      log.info "Definition: #{sum["description"]}"
      # get fasta files
      new_items = get_genome_info( fasta_loc, sum["uid"])
      list = list.concat new_items

      if new_items.size == 0
        log.info "not adding new items for uid: #{sum["uid"]}"
      else
        log.debug "adding #{new_items.size} new items"
      end

    end

    # iterate the list to build the url
    url = {}
    url["id"]    = []
    url["seq_start"] = []
    url["seq_stop"]   = []
    list.each do |el|
      url["id"]   << el[:accver]
      url["seq_start"] << el[:start]
      url["seq_stop"]   << el[:end]
    end

    log.debug "building url with #{url["id"].size} ids, #{url["seq_start"].size} seq_starts and #{url["seq_stop"].size} seq_stops"

    # get the uri
    url[:uri] = build_download_url(url, "fasta", "text")
    response = api( url[:uri] )

    # download all fasta files and save in ntseq
    @ntseq = response
  end

  #
  #
  # search the database with a given term
  def find(term, field="")
    list = find_recursive( term, field )
    new_ncbi = NCBIAPI.new summaries(list)
    new_ncbi
  end

  #
  #
  # static method to translate keys to
  #  description and parent organism
  def self.translate( )
    translation = Hash.new
    ncbi = NCBIAPI.new
    File.open "translate-ncbi.out.txt", 'w' do |fw|
      File.open "translate.txt", 'r' do |f|
        keys = f.read.split( /\n/ )
        keys.each do |el|
          # take only kegg lines
          next unless el.start_with?(TRANSLATION_PREFIX)
          # replace prefix with void
          el = el.gsub Regexp.new("^" + TRANSLATION_PREFIX + " "), ""
          resp = ncbi.summaries([el])[el]

          translation[el] = {}
          translation[el][:uid]        = resp["uid"]
          translation[el][:definition] = resp["description"]
          translation[el][:organism]   = resp["orgname"]
          translation[el][:organism] += " (#{resp["organism"]["commonname"]})" unless resp["organism"]["commonname"].empty?
          fw.puts [translation[el][:uid], translation[el][:definition],translation[el][:organism]].join("\t")
        end
      end
    end
    translation
  end

  private

  #
  #
  # recursive function to search the database with a given term
  def find_recursive(term,field,retstart=0)
    json_doc = api( build_search_url( term, field, retstart ))
    results = json_doc["esearchresult"]

    list = results["idlist"]

    if results["retstart"].to_i < results["count"].to_i
      log.debug "retmax: #{results["retmax"]} - count: #{results["count"]} - start: #{results["retstart"]}"
      list = list.concat( find_recursive(term, field, results["retmax"] + results["retstart"]) )
    end
    list
  end

  #
  #
  #
  def build_search_url(term, field="", retstart=0, retmode="json")
    term = URI.escape term
    field = URI.escape field
    uri = URI.parse BASE_PATH + SEARCH_PREFIX + "db=#{SEARCH_DB}&term=#{term}&field=#{field}&retstart=#{retstart}&retmode=#{retmode}"
    uri
  end

  #
  #
  # API
  def api(url)
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.request(req)
    end
    #
    parse(res.body) # convert from response to hash
  end

  def parse(body)
    json_doc = begin
      JSON.parse(body)
    rescue
        body
    end

  end

  #
  #
  #
  def build_url( hash, rettype, retmode, prefix, db )
    uri = BASE_PATH + prefix + "db=#{db}&rettype=#{rettype}&retmode=#{retmode}"
    log.debug "uri before hash: " + uri.to_s
    hash.each_pair do |key, val|
      val = [val] if val.is_a? String
      uri += "&#{key.to_s}=#{val.join(',')}"
    end
    log.debug "uri after hash: " + uri.to_s

    URI.parse uri
  end

  #
  #
  #
  def build_summary_url( ids, rettype, retmode ) build_url({"id" => ids}, rettype, retmode, SUMMARY_PREFIX, SEARCH_DB) end
  def build_download_url( hash, rettype, retmode ) build_url(hash, rettype, retmode, DOWNLOAD_PREFIX, FASTA_DB) end

end
