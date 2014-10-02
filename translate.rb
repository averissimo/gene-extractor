require './ncbi.rb'
require './kegg.rb'
require 'logger'

logger = Logger.new(STDOUT)
logger.level = Logger::INFO


logger.info "translating ncbi entries of translate.txt ..."
NCBIAPI::translate
logger.info "  success! open translate-ncbi.out.txt to see the results"
logger.info "translating kegg entries of translate.txt ..."
KeggAPI::translate
logger.info "  success! open translate-kegg.out.txt to see the results"
logger.info "exiting now :)"
