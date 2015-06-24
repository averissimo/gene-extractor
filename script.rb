require './ncbi.rb'
require './kegg.rb'
require './kegg_enzyme.rb'
require 'yaml'
require 'logger'
require 'fileutils'
#require 'byebug'

class DownloadGenes

  def log() @logger end

  def initialize

    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO

    # load configuration
    config = YAML.load_file('config.yml')

    # create parent output directories
    @dir_prefix = config["output"]["dir"]
    FileUtils.mkdir @dir_prefix unless Dir.exists?(@dir_prefix)
    if config["output"]["date_prefix"]
      @dir_prefix = File.join( config["output"]["dir"], Time.now.strftime('%Y-%m-%d-%H-%M-%S.%L') + "_" + rand(1000000).to_s )
      FileUtils.mkdir @dir_prefix unless Dir.exists?(@dir_prefix)
    end
    @kegg_dir          = config["output"]["kegg"]
    @kegg_enzyme_dir   = config["output"]["kegg_enzyme"]
    @kegg_compound_dir = config["output"]["kegg_compound"]
    @ncbi_dir = config["output"]["ncbi"]
    # get email
    @email = config["email"]
    # get array of fields to look
    @search = config["search"]["ncbi"]
    # read query file
    read_query_file
    # read enzymes file
    read_enzyme_file
    # read compound file
    read_compound_file
  end

  def read_query_file
    File.open "keys.txt", 'r' do |f|
      @queries = f.read.split("\n")
    end
    @queries
  end

  def read_enzyme_file
    File.open "enzymes.txt", 'r' do |f|
      @enzymes = f.read.split("\n")
    end
    @enzymes
  end

  def read_compound_file
    File.open "compounds.txt", 'r' do |f|
      @compounds = f.read.split("\n")
    end
    @enzymes
  end

  def kegg_compound
    kegg = KeggEnzyme.new

    @compounds.each do |query|

      # create results dir
      dirname = File.join(@dir_prefix, @kegg_compound_dir)
      Dir.mkdir dirname unless Dir.exists? (dirname)

      log.info "Starting Compound query (KEGG): #{query}"
      result = kegg.get_genes_from_compound(query)
      File.open File.join(dirname,query + ".query"), 'w' do |fw|
        #
        result.each do |res|
          fw.puts res
        end
      end
      log.info "---------------"
    end
  end

  def kegg_enzyme
    kegg = KeggEnzyme.new

    @enzymes.each do |query|

      # create results dir
      dirname = File.join(@dir_prefix, @kegg_enzyme_dir)
      Dir.mkdir dirname unless Dir.exists? (dirname)

      log.info "Starting Enzyme query (KEGG): #{query}"
      result = kegg.get_genes_from_enzyme(query)
      File.open File.join(dirname,query + ".query"), 'w' do |fw|
        #
        result.each do |res|
          fw.puts res
        end
      end
      log.info "---------------"
    end
  end

  def kegg
    kegg = KeggAPI.new

    @queries.each do |query|
      search = kegg.find_genes(query)
      keys = search.response.keys
      log.debug "keys: " + keys.join(", ")

      # create results dir
      dirname = File.join(@dir_prefix, @kegg_dir)
      Dir.mkdir dirname unless Dir.exists? (dirname)

      log.info "Starting Gene query (KEGG): #{query}"
      result = search.download_genes()
      File.open File.join(dirname,query + ".query"), 'w' do |fw|
        #
        result.each do |res|
          fw.puts res.ntseq
        end
      end
      log.info "---------------"
    end
  end

  def ncbi()
    ncbi = NcbiAPI.new @email
    #
    @queries.each do |query|
      #
      dirname = File.join @dir_prefix, @ncbi_dir
      Dir.mkdir dirname unless Dir.exists? (dirname)
      #
      log.info "Starting Gene query (NCBI): #{query}"
      result_list = ncbi.find(query,@search)

      File.open File.join(dirname,query + ".query"), 'w' do |fw|
        #
        genes = result_list.download_genes

        genes.each do |gene|
          fw.puts gene.ntseq unless gene.ntseq.nil?
        end
        #
      end
      log.info "---------------"
    end
  end

end

genes = DownloadGenes.new
genes.ncbi()
genes.kegg()
genes.kegg_enzyme()
genes.kegg_compound()

#require 'pry'
#binding.pry
