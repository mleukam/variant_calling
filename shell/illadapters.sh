## Script to mark illumina adapter sequences in unaligned BAM files
## Input is unaligned BAM files (uBAM)
## Output is -XT tagged BAM files named *_markilluminaadapters.BAM
## Built specifically for 1000k DLBCL project
## Designed for batch submission to Gardner HPC at UChicago
## First line = shebang to specify interpretor (bash)
## Before using, use chmod to make executable

#!/bin/bash

## Set script to fail if any command, variable, or output fails
set -euo pipefail

## Set IFS to split only on newline and tab
IFS=$'\n\t'

## Load compiler
module load java-jdk/1.8.0_92

## Load necessary modules
## NB: the path to picard.jar is automatically generated as an environment variable when picard tool module is loaded
## location of picard.jar = ${PICARD}
module load picard/2.8.1

## Navigate to directory containing unaligned BAM files
cd /scratch/mleukam/dave_subset

## Define the input files as an array
BAMLIST=($(ls *_revertsam.bam))

## Pull the sample name from the input file names and make new array
SMLIST=(${BAMLIST[*]%_*})

## loop to run MarkIlluminaAdapters on all of the uBAM files in the directory
for SAMPLE in ${SMLIST[*]}; 
do 
	java -Xmx8G -jar ${PICARD} MarkIlluminaAdapters \
	I=${SAMPLE}_revertsam.bam \
	O=${SAMPLE}_markilluminaadapters.bam \
	M=${SAMPLE}_markilluminaadapters_metrics.txt \
	TMP_DIR=/group/kline-lab/temp/; #optional to process large files
done

