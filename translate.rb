require './ncbi.rb'
require './kegg.rb'
require 'logger'
require 'yaml'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO

config = YAML.load_file('config.yml')
email = config["email"]

logger.info "translating ncbi entries of translate.txt ..."
NcbiAPI::translate(email)
logger.info "  success! open translate-ncbi.out.txt to see the results"
logger.info "translating kegg entries of translate.txt ..."
KeggAPI::translate
logger.info "  success! open translate-kegg.out.txt to see the results"
output="dictionary.csv"
File.open output, "w+" do |f|
  f.write("id\tdescription\torganism\n")
  f.write File.read("translate-ncbi.out.txt")
  f.write File.read("translate-kegg.out.txt")
end
logger.info "exiting now :)"
