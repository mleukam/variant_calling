## Script to convert previously aligned BAM files to unaligned (uBAM) format
## Built specifically for WES data from 1kDLBCL project
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

## Navigate to directory containing fastq files
cd /scratch/mleukam/dave_subset

#############
# MAKE UBAM #
#############

# define the input variables as an array
BAMLIST=($(ls *.bam))

# pull the sample name from the input file names and make new array
SMLIST=(${BAMLIST[*]%.bam})

# revert aligned BAM to unaligned BAM and add readgroup information
# returns unaligned BAM to the same directory
for SAMPLE in ${SMLIST[*]}; 
do
	java -Xmx32G -jar ${PICARD} RevertSam \
    I=${SAMPLE}.bam \
    O=${SAMPLE}_revertsam.bam \
    SANITIZE=true \
    MAX_DISCARD_FRACTION=0.005 \
    ATTRIBUTE_TO_CLEAR=XT \
    ATTRIBUTE_TO_CLEAR=XN \
    ATTRIBUTE_TO_CLEAR=AS \
    ATTRIBUTE_TO_CLEAR=OC \
    ATTRIBUTE_TO_CLEAR=OP \
    SORT_ORDER=queryname \
    RESTORE_ORIGINAL_QUALITIES=true \
    REMOVE_DUPLICATE_INFORMATION=true \
    REMOVE_ALIGNMENT_INFORMATION=true
    TMP_DIR=/scratch/mleukam/temp;
done
