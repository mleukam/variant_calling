# Variant Calling Pipeline for WES data

Specically designed for DLBCL project

## Preparation
Before performing analysis, some additional files need to be prepared. Scripts will be included in the pipeline but only need to be run once for each dataset.

1. _Target list_: For this project the exomic DNA was captured with Agilant SureSelect Human All Exon V5 bait set. BED and txt files for this primer set are available for download [here](https://earray.chem.agilent.com/suredesign/search.htm) (account required). Note: BED and txt files are all generated on hg19!
2. _Panel of Normals_: No normal/germline WES data is available for this project. The panel of normals was generated using whole exome sequences from 1000 genomes project (http://www.internationalgenome.org/data-portal)
3. 
