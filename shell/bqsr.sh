#
## This script runs a two-stage process called Base Quality Score Recalibration (BQSR).
## Specifically, it produces a recalibrated table with the BaseRecalibrator tool
## It then outputs a recalibrated BAM or CRAM file.
## Input is aligned BAM files with duplicates marked
## Outputs are a recalibration table and a recalibrated BAM
## Usage = ./recalbases.sh inside PBS script
## Built specifically for 1k DLBCL project
## Designed for batch submission to Gardner HPC at UChicago
## First line = shebang to specify interpretor (bash)
## Before using, use chmod to make executable
#
#!/bin/bash
#
## Set script to fail if any command, variable, or output fails
#
set -euo pipefail
#
## Set IFS to split only on newline and tab
#
IFS=$'\n\t'
#
## Load compiler
#
module load java-jdk/1.8.0_92
#
## Load necessary modules
## NB: the path to GATK is automatically generated as an environment variable
## Location of GenomeAnalysis.jar = ${GATK}
#
module load gatk/4.0.6.0
#
## Navigate to directory with input aligned and merged BAM files
#
cd /scratch/mleukam/dave_subset
#
## Define the input files as an array
#
BAMLIST=($(ls *_markduplicates.bam))
#
## Pull the sample name from the input file names and make new array
#
SMLIST=(${BAMLIST[*]%_*})
#
## For loop iterating over samples in target folder
#
for SAMPLE in ${SMLIST[*]};
do 
#
## Analyze patterns of covariation in the sequence dataset
## Known site filters for downstream variant calling include:
## 1. dbSNP database build 151
## 2. Mills and 1000 genome project standard indels
## 3. 1000 genome project phase 1 high confidence SNPs
## All stored in /group/kline-lab/ref/
#
	java -Xmx16G -jar ${GATK} BaseRecalibrator \
    	-R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    	-I ${SAMPLE}_markduplicates.bam \
   		--known-sites /group/kline-lab/ref/dbsnp_151.vcf \
    	--known-sites /group/kline-lab/ref/Mills_and_1000G_gold_standard.indels.hg38.vcf \
    	--known-sites /group/kline-lab/ref/1000G_phase1.snps.high_confidence.hg38.vcf \
    	-O ${SAMPLE}_bqsr.table;
#
## Apply the recalibration to the sequence data
#
	java -Xmx16G -jar ${GATK} ApplyBQSR \
		-R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    	-I ${SAMPLE}_addRG.bam \
    	--bqsr-recal-file ${SAMPLE}_bqsr.table \
    	-O ${SAMPLE}_bqsr.bam;
 done
#