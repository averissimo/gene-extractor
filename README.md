Gene Extractor
==============

Searchs independent search term against different databases
- KEGG [link](http://www.genome.jp/kegg/kegg2.html)
- GenBank [link](http://www.ncbi.nlm.nih.gov/genbank)

## Requirements

- Ruby runtime environment
- Bundle Gem

## How to Use

1. Run `bundle install`
1. Create a keys.txt (either by copying keys.txt.example or creating a blank one)
1. Add query terms to keys.txt (separated by a new line)
1. Run `ruby script.rb` to search and download all the associated genes

## Ackowledgements

This tool was created as a part of [FCT](www.fct.p) grant SFRH/BD/97415/2013 and European Commission research project [BacHBerry](www.bachberry.eu) (FP7- 613793)
