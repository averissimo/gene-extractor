require 'net/http'
require 'logger'

#
#
# Each call to a specific operation will generate
#  a new KeggAPI object with the response.
# The design change to this behaviour in order to
#  be able to call multiple methods in a row such as:
#  - kegg.query().download
class KeggAPI

  GET_PREFIX = "http://rest.kegg.jp/"
  NT_SEQ = :NTSEQ
  ORGANISM = :ORGANISM
  ENTRY = :ENTRY
  DEFINITION = :DEFINITION
  TRANSLATION_PREFIX = "kegg"

  SEP = "/"

  REST_LINE_SEP   = /\n/
  REST_LINE       = /^([\S]+)?([\s]+)(.+)/
  REST_END        = /\/\/\//

  def log() @logger end

  #
  #
  # Constructor, may receive a response to work on
  def initialize(response=nil)

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    log.debug "creating a new KeggAPI object..." if response.nil?

    @response = response
  end

  #
  #
  # main method that communicates with the REST interface
  #  and performs an initial processing of the respone into
  #  and hash
  # the argument can be a single string or an array of strings.
  #  when it is an array it will join all the elements into a
  #  single string separated by "/" (the SEP constant)
  def api(argument, operation="get")
    log.debug "calling api() with operation=" + operation.to_s + " and argument=" + argument.to_s
    # join args with "/" separator if it is not a single string
    args = argument.is_a?(String) ? argument : argument.join(SEP)
    # get url
    url = URI.parse GET_PREFIX + operation + SEP + args
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    # convert from response to hash and generates the new object
    #  with the response
    response = parse(res.body)
    log.debug "response: " + res.response.to_s
    new_obj = KeggAPI.new( response )
    new_obj
  end

  #
  # just a getter method to get the response stored in object
  def response
    @response
  end

  #
  # interface to use "get" rest method
  def download(argument)
    res = api(argument,"get")
    log.info "  Definition (#{argument}): #{res.definition}"
    res
  end

  #
  # method to search the KEGG2 database for a give
  #  set of keywords
  def find(query)
    response = api(query,"find")
    log.info " -> #{response.response.size} results"
    response
  end

  #
  #
  # queries the rest API for genes with the speficif query
  def find_genes(query)
    find( ['genes', URI::escape("\"#{query}\"")] )
  end

  #
  #
  # simple interface to get definition
  def definition(response=nil)
    response = @response if response.nil?
    response[DEFINITION].first
  end

  #
  #
  # simple interface to get organism
  def organism(response=nil)
    response = @response if response.nil?
    response[ORGANISM].first.gsub /^[\S]+ /, "" # replace beginning if starts with acronyom
  end

  #
  # interface to get all the ntseq data
  def ntseq(response=nil)
    response = @response if response.nil?

    return nil if response.nil?

    data = response[NT_SEQ]

    # first is the size
    size = data.shift

    seq = data.join("\n")
    header = ">" + response[ORGANISM].first.split.first + ":" + response[ENTRY].first.split.first + " " + response[DEFINITION].first
    [header, seq, ""].join("\n")
  end

  #
  #
  # static method to translate keys to
  #  description and parent organism
  def self.translate( )
    translation = Hash.new
    kegg = KeggAPI.new
    File.open "translate-kegg.out.txt", 'w' do |fw|
      File.open "translate.txt", 'r' do |f|
        keys = f.read.split( /\n/ )
        keys.each do |el|
          # take only kegg lines
          next unless el.start_with?(TRANSLATION_PREFIX)
          # replace prefix with void
          el = el.gsub Regexp.new("^" + TRANSLATION_PREFIX + " "), ""
          resp = kegg.download(el)
          translation[el] = {}
          translation[el][:definition] = resp.definition
          translation[el][:organism]   = resp.organism
          fw.puts [el, translation[el][:definition], translation[el][:organism]].join("\t")
        end
      end
    end
    translation
  end

  private

  # method that parses the response in text to an
  #  hash
  def parse body
    # parse by line
    response    = Hash.new # response hash
    # auxiliary to know last head for
    #  data that goes over one line
    last_head = nil
    #
    body.split(REST_LINE_SEP).each do |line|
      #
      break unless line.match(REST_END).nil?
      #
      match = line.match REST_LINE
      #
      unless match[1].nil?
        last_head         = match[1].to_sym
        response[last_head] = [ ]
      end
      response[last_head] << match[3]
      #
    end
    response
  end

end
