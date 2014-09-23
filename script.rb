#require 'byebug'

# require 'pry'

require './ncbi.rb'
require './kegg.rb'

class DownloadGenes

  def initialize
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
    # res = kegg.api("ath:AT1G03940")
    @queries.each do |query|

      search = kegg.find(["genes",query])

      # create results dir
      dir_name =  "kegg_queries" # Time.new.strftime("%Y-%m-%d-%H-%M-%S") + "-" + ( '%04d' % rand(1000))
      Dir.mkdir dir_name unless Dir.exists? (dir_name)

      puts "Starting with query (KEGG): #{query}"
      File.open File.join(dir_name,query + ".query"), 'w' do |fw|
        #
        search.keys.each do |i|
          key = i.to_s
          res = kegg.download( key )

          puts "  Definition: #{kegg.definition(res)}"

          fw.puts kegg.ntseq( res )
        end
      end
      puts "---------------"
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
      puts "Starting with query (NCBI): #{query}"
      File.open File.join(dir_name,query + ".query"), 'w' do |fw|
        #
        result = ncbi.download(result_list)
        puts "File size: " + result.size.to_s
        fw.puts result
        #
      end
      puts "---------------"
    end
  end

end

genes = DownloadGenes.new
genes.ncbi( "Gene/Protein Name" )
genes.kegg()

# binding.pry
