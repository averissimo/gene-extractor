require 'net/http'
require 'rexml/document'
require 'byebug'
require 'json'
require 'logger'

class NCBIAPI

  BASE_PATH = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

  DOWNLOAD_PREFIX = "efetch.fcgi?"
  SEARCH_PREFIX = "esearch.fcgi?retmode=json&retmax=200&"

  SEARCH_DB = "gene"
  FASTA_DB  = "nuccore"

  def initialize()
    @log = Logger.new(STDOUT)
  end

  def download(list)
    api( build_download_url(list) )
  end

  def find(term,field="",retstart=0)
    json_doc = api( build_search_url( term, field, retstart ))
    results = json_doc["esearchresult"]
    list = results["idlist"]

    if results["retmax"] < results["count"]
      list = list.concat( find(term, field, results["retmax"]) )
    end
    list
  end

  def build_download_url(ids)
    ids = [ids] if ids.is_a? String
    uri = URI.parse BASE_PATH + DOWNLOAD_PREFIX + "db=#{FASTA_DB}&id=#{ids.join(',')}&rettype=fasta&retmode=text"
    uri
  end

  def build_search_url(term, field="", retstart=0)
    term = URI.escape term
    field = URI.escape field
    uri = URI.parse BASE_PATH + SEARCH_PREFIX + "db=#{SEARCH_DB}&term=#{term}&field=#{field}&retstart=#{retstart}"
    uri
  end

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

end
