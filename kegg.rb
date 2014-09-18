require 'net/http'
require 'byebug'

class KeggAPI

  GET_PREFIX = "http://rest.kegg.jp/"
  NT_SEQ = :NTSEQ
  ORGANISM = :ORGANISM
  ENTRY = :ENTRY
  DEFINITION = :DEFINITION

  SEP = "/"

  REST_LINE_SEP   = /\n/
  REST_LINE       = /^([\S]+)?([\s]+)(.+)/
  REST_END        = /\/\/\//

  # get an argument from kegg REST API
  def api(argument, operation="get")
    # join args with "/" separator
    args = argument.is_a?(String) ? argument : argument.join(SEP)
    # get url
    url = URI.parse GET_PREFIX + operation + SEP + args
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    #
    parse(res.body) # convert from response to hash
  end

  def download(argument)
    api(argument,"get")
  end

  def find(query)
    api(query,"find")
  end

  def definition(result)
    result[DEFINITION]
  end

  def ntseq(result)
    return nil if result.nil?

    data = result[NT_SEQ]

    # first is the size
    size = data.shift

    seq = data.join("\n")
    header = ">" + result[ORGANISM].first.split.first + ":" + result[ENTRY].first.split.first + " " + result[DEFINITION].first
    [header, seq, ""].join("\n")
  end

  private

  # method that parses the response in text to an
  #  hash
  def parse body
    # parse by line
    result    = Hash.new # result hash
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
        result[last_head] = [ ]
      end
      result[last_head] << match[3]
      #
    end
    result
  end

end
