require './kegg.rb'
require 'byebug'
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
      genes_query = response[:GENES].collect do |value|
        genes = value.split
        species = genes.shift().downcase() # get first position
        genes.collect do |g|
          species.to_s + g.gsub(/[(][^\).]+[)]/, '')
        end
      end.flatten
      log.info("      -> found #{genes_query.size} genes for this enzyme (#{enz})")
      #
      genes_query.each_with_index do |gene,index|
        gene_result = api(gene)
        if (index + 1) % 10 == 0 || index == 0
          log.info("        -> finished downloading gene #{index + 1}/#{genes_query.size}")
        end
        gene_result.ntseq(nil,enz)
      end
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
    result = nil if enzymes.nil?

    result = enzymes.collect do |item|
      item.split /[ \t]+/
    end.flatten.compact
    log.info("    -> found #{result.nil? ? '0' : result.size} enzymes in this compound data (#{compound_id})")
    result
  end

end
