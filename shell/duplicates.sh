## Script to mark duplicates in merged "clean" BAM files
## Input is aligned BAM files after merger with uBAM (output of mlalign.sh)
## Output is marked BAM file
## Built specifically for WES data that was transferred 8/2/18
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
BAMLIST=($(ls *_piped.bam))

## Pull the sample name from the input file names and make new array
SMLIST=(${BAMLIST[*]%_*})

## loop to run MarkIlluminaAdapters on all of the uBAM files in the directory
for SAMPLE in ${SMLIST[*]}; 
do 
	java -Xmx32G -jar ${PICARD} MarkDuplicates \
	INPUT=${SAMPLE}_piped.bam \
	OUTPUT=${SAMPLE}_markduplicates.bam \
	METRICS_FILE=${SAMPLE}_markduplicates_metrics.txt \
	OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
	CREATE_INDEX=true \
	TMP_DIR=/scratch/mleukam/temp;
done
