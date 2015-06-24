require './kegg.rb'

#
#
# Each call to a specific operation will generate
#  a new KeggEnzyme object with the response.
# The design change to this behaviour in order to
#  be able to call multiple methods in a row such as:
#  - kegg.query().download
class KeggEnzyme < KeggAPI

  #
  #
  # Search the compound db for the query term
  #
  def findCompound(query)
    find( ['compound', URI::escape("\"#{query}\"")] )
  end

  #
  #
  # Get all genes from a compound
  #
  def get_genes_from_compound(query)
    #  start by searching for the compound
    compounds = findCompound(query)
    result = {}
    nt_to_download = []
    # get all enzymes in compound
    compounds.response.keys.each do |key|
      compound_id = key.to_s
      result[compound_id.to_s] = enzymes_in_compound(compound_id)

      next if result[compound_id.to_s].nil?
      result[compound_id.to_s].each do |enz|
        nt_to_download << get_genes_from_enzyme(enz)
      end

    end # return an array of enzymes id
    result
    #

    # from all enzymes get the nt seq
    nt_to_download.flatten.compact
  end

  #
  #
  # get an array of genes from the enzyme
  #
  def get_genes_from_enzyme(enz)
    response = get_enzyme(enz)
    if response[:GENES]
      # some genes might
      gene_queue = Queue.new
      response[:GENES].each do |value|
        genes = value.split
        species = genes.shift().downcase() # get first position
        genes.collect do |g|
          gene_queue << species.to_s + g.gsub(/\(.+\)$/, '')
        end
      end
      log.info("      -> found #{gene_queue.size} genes for this enzyme (#{enz})")
      #
      threads = []
      # multi-thread!!
      NUM_THREADS.times.each do
        threads << Thread.new do
          #
          result = []
          until gene_queue.size == 0
            gene = gene_queue.pop
            gene_result = api(gene)
            log.info("        -> finished downloading gene (#{gene} - with #{gene_queue.size} in queue)")
            result << gene_result.ntseq(nil,enz)
          end
          result
          #
        end
      end

      result = []
      result = threads.collect do |thr|
        thr.value
      end.flatten.compact
      return result
    else
      log.info("      -> found 0 genes for this enzyme (#{enz})")
      return []
    end
  end

  #
  #
  #
  #
  def get_enzyme(enzyme)
    api("ec:#{enzyme}").response
  end

  def enzymes_in_compound(compound_id)
    enzymes = api(compound_id).response[:ENZYME]
    result = if enzymes.nil?
      nil
    else
      result = enzymes.collect do |item|
        item.split /[ \t]+/
      end.flatten.compact
    end
    log.info("    -> found #{result.nil? ? '0' : result.size} enzymes in this compound data (#{compound_id})")
    result
  end

end
