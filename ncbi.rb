require 'net/http'
require 'byebug'
require 'json'
require 'logger'
require 'rexml/document'

class NCBIAPI

  BASE_PATH = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/"

  DOWNLOAD_PREFIX = "efetch.fcgi?"
  SEARCH_PREFIX = "esearch.fcgi?retmode=json&retmax=200&"

  SEARCH_DB = "gene"
  FASTA_DB  = "nuccore"

  def initialize()
    @log = Logger.new(STDOUT)
  end

  def download(list,rettype="fasta",retmode="text")
    api( build_download_url(list, rettype, retmode) )
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

  def build_download_url( ids, retype, retmode )
    ids = [ids] if ids.is_a? String
    uri = URI.parse BASE_PATH + DOWNLOAD_PREFIX + "db=#{FASTA_DB}&id=#{ids.join(',')}&rettype=#{rettype}&retmode=#{retmode}"
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
      begin

      rescue
        body
      end
    end

  end

  #
  #
  # static method to translate keys to
  #  description and parent organism
  def self.translate( )
    translation = Hash.new
    ncbi = NCBIAPI.new
    File.open "translate-kegg.out.txt", 'w' do |fw|
      File.open "translate.txt", 'r' do |f|
        keys = f.read.split( /\n/ )
        keys.each do |el|
          # take only kegg lines
          next unless el.start_with?(TRANSLATION_PREFIX)
          # replace prefix with void
          el = el.gsub Regexp.new("^" + TRANSLATION_PREFIX + " "), ""
          resp = ncbi.download(el, "fasta", "xml")

          xml_doc = REXML::Document.new(resp)



          translation[el] = {}
          translation[el][:definition] = resp.definition
          translation[el][:organism]   = resp.organism
          fw.puts translation[el][:definition] + "\t" + translation[el][:organism]
        end
      end
    end
    translation
  end

end
