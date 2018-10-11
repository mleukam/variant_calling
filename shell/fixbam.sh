## Script to repair sample names in 1000 genome BAM files
## This is required before variant calling to create panel of normals
## In the future this script should be unnecessary and is therefore a custom script
## Input is 1000 genome CRAM files that were converted to BAM
## Output is marked BAM file with corrected read information
## Usage = ./mlfixbam.sh inside PBS script
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

# navigate to the directory containing panel of normal input files
cd /gpfs/data/kline-lab/ref/1000G_PoN/
#
# gather the desired input files in the directory as an array
BAMLIST=($(ls *.bam))

# pull the sample name from the input file names and make new array
SMLIST=(${BAMLIST[*]%.*})
#
# replace sample names with full sample name
for SAMPLE in ${SMLIST[*]};
do 
    java -Xmx8G -jar ${PICARD} AddOrReplaceReadGroups \
    INPUT=${SAMPLE}.bam \
    OUTPUT=${SAMPLE}_repaired.bam \
    RGID=Z:SRR766045 \
    RGLB=library1 \
    RGPL=illumina \
    RGPU=20150826 \
    RGSM=${SAMPLE}_repaired \
    SORT_ORDER=coordinate \
    CREATE_INDEX=true \
    TMP_DIR=/scratch/mleukam/temp;
done
