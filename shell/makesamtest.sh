## Script for converting BAMs without EOF tag to SAMs
## Built specifically for WES data from 1kDLBCL project
## Designed for batch submission to Gardner HPC at UChicago
## First line = shebang to specify interpretor (bash)
## Before using, use chmod to make executable

#!/bin/bash

## Set script to fail if any command, variable, or output fails
set -euo pipefail

## Set IFS to split only on newline and tab
IFS=$'\n\t'

echo "*** run by `whoami` on `date`" > /home/mleukam/runlog.makesam.txt

## Load compiler
module load gcc/6.2.0
module load java-jdk/1.8.0_92

## Load necessary modules
module load samtools
module load picard/2.8.1

## Navigate to directory containing BAM files
cd /scratch/mleukam/wes_data

## For loop for converstion of bam --> sam
echo "*** starting conversion of bam to sam"
file=EGAR00001587909_790.a.1kDLBCL_FFPEvsFrozen.DLBCL.SL105409.exome_1tier.hg19.final.bam
echo $file; 
samtools view -h $file > ${file/.bam/.sam}; 
echo "*** bam files converted to sam"

## Define the input variables as an array
## To get only one copy of the sample name, I will pick only files ending in "1",
## ignore the paired "2" file for this list
fslist=($(ls *.final.sam))

## Pull the sample name from the input file names and make new array
smlist=(${fslist[*]%.final.sam})

## Loop to convert SAM back to BAM (with EOF tag)
## Then convert to unaligned BAM and strip off problematic header info for downstream analysis
echo "*** starting conversion of sam to ubam"
for sample in ${smlist[*]}; 
do
	samtools view -S -b ${sample}.final.sam > ${sample}.start.bam
	java -Xmx16G -jar ${PICARD} RevertSam \
    I=${sample}.start.bam \
    O=${sample}_revertsam.bam \
    SANITIZE=true \
    MAX_DISCARD_FRACTION=0.3 \
    ATTRIBUTE_TO_CLEAR=XT \
    ATTRIBUTE_TO_CLEAR=XN \
    ATTRIBUTE_TO_CLEAR=AS \
    ATTRIBUTE_TO_CLEAR=OC \
    ATTRIBUTE_TO_CLEAR=OP \
    SORT_ORDER=queryname \
    RESTORE_ORIGINAL_QUALITIES=true \
    REMOVE_DUPLICATE_INFORMATION=true \
    REMOVE_ALIGNMENT_INFORMATION=true \
    TMP_DIR=/scratch/mleukam/temp;
done
echo "*** sam files converted to ubam"

## clean up
rm *.sam
echo "*** temporary files removed"
echo "*** done"