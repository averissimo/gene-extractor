GeneExtractor
==============

Searchs independent terms against different databases and retrieves gene sequences from:
- KEGG - [link](http://www.genome.jp/kegg/genes.html)
- NCBI Nucleotide - [link](http://www.ncbi.nlm.nih.gov/nuccore/)

## Requirements

- [Ruby runtime environment](https://www.ruby-lang.org/en/installation/)
 - [Windows](http://rubyinstaller.org/)
 - [Mac OSX and Linux](http://rvm.io/)
- Bundle Gem - `gem install bundle`
- [Bioruby gem](http://www.bioruby.org)

## How to Use

1. Run `bundle install` to install dependencies *(currently only Bioruby)*
1. Create a `keys.txt` file *(either by copying keys.txt.example or creating a blank one)*
 - Add query terms to keys.txt *(separated by new lines)*
1. Create a `config.yml` file *(either by copying keys.txt.example or creating a blank one)*
 - Open the file and change options (if need be)
1. Run `ruby script.rb` to search and download all the associated genes

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)

[Developer](http://web.tecnico.ulisboa.pt/andre.verissimo/)
