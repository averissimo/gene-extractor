#require 'byebug'

# require 'pry'

require './ncbi.rb'
require './kegg.rb'
require 'logger'

class DownloadGenes

  def log() @logger end

  def initialize

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    read_query_file
  end

  def read_query_file
    File.open "keys.txt", 'r' do |f|
      @queries = f.read.split("\n")
    end
    @queries
  end

  def kegg
    kegg = KeggAPI.new

    @queries.each do |query|

      search = kegg.find_genes(query).response
      keys = search.keys
      log.debug "keys: " + keys.join(", ")

      # create results dir
      dir_name =  "kegg_queries" # Time.new.strftime("%Y-%m-%d-%H-%M-%S") + "-" + ( '%04d' % rand(1000))
      Dir.mkdir dir_name unless Dir.exists? (dir_name)

      log.info "Starting with query (KEGG): #{query}"
      File.open File.join(dir_name,query + ".query"), 'w' do |fw|
        #
        keys.each do |i|
          key = i.to_s
          res = kegg.download( key )

          log.info "  Definition: #{res.definition}"

          fw.puts res.ntseq
        end
      end
      log.info "---------------"
    end
  end

  def ncbi(field="")
    ncbi = NCBIAPI.new
    #
    @queries.each do |query|
      #
      dir_name =  "ncbi_queries" # Time.new.strftime("%Y-%m-%d-%H-%M-%S") + "-" + ( '%04d' % rand(1000))
      Dir.mkdir dir_name unless Dir.exists? (dir_name)
      #
      result_list = ncbi.find(query,field)
      #
      log.info "Starting with query (NCBI): #{query}"
      File.open File.join(dir_name,query + ".query"), 'w' do |fw|
        #
        result = ncbi.download(result_list)
        puts "File size: " + result.size.to_s
        fw.puts result
        #
      end
      log.info "---------------"
    end
  end

end

genes = DownloadGenes.new
#genes.ncbi( "Gene/Protein Name" )
genes.kegg()

# binding.pry
