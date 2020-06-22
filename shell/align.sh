## Multi-step, piped script
## 1. Convert uBAM files back to fastq
## 2. Align to reference genome with BWA MEM
## 3. Merge aligned BAM file with uBAM file to create "clean" BAM
## Input is uBAM with flagged illumina adapters named *_markilluminaadapters.BAM
## Output is merged BAM file
## Built specifically for WES data that was transferred 8/2/18
## Designed for batch submission to Gardner HPC at UChicago
## First line = shebang to specify interpretor (bash)
## Before using, use chmod to make executable
## Before using ensure that Picard tools reference dictionary and BWA index are ready

#!/bin/bash

## Set script to fail if any command, variable, or output fails
set -euo pipefail

## Set IFS to split only on newline and tab
IFS=$'\n\t'

## Load compilers
module load gcc/6.2.0
module load java-jdk/1.8.0_92

## Load necessary modules
## The path to picard.jar is automatically generated as an environment variable when picard tool module is loaded
## location of picard.jar = ${PICARD}
module load picard/2.8.1
module load bwa/0.7.17

## Navigate to directory containing unaligned BAM files
cd /scratch/mleukam/dave_subset/

## Gather the desired input files in the directory as an array
ILLBAMLIST=($(ls *_markilluminaadapters.bam))

## Pull the sample name from the input file names and make new array
SMLIST=(${ILLBAMLIST[*]%_*})

## Loop to run pipeline on all of the called files in the directory
## Note that t flag in bwa is set to 28 for number of cores in each Gardner node
## The reference genome used in this case is GRCh38 with decoys: GRCh38_full_plus_hs38d1_analysis_set
## Analysis set is processed as recommended by Heng Li, writer of BWA
## See http://lh3.github.io/2017/11/13/which-human-reference-genome-to-use for more
## Index file for bwa downloaded with reference genome from NCBI
for SAMPLE in ${SMLIST[*]}; 
do 
	java -Xmx8G -jar ${PICARD} SamToFastq \
	I=${SAMPLE}_markilluminaadapters.bam \
	FASTQ=/dev/stdout \
	CLIPPING_ATTRIBUTE=XT CLIPPING_ACTION=2 INTERLEAVE=true NON_PF=true \
	TMP_DIR=/scratch/mleukam/temp | \
	bwa mem -M -t 28 -p /group/kline-lab/ref/GRCh38_full_plus_decoy.fa /dev/stdin | \
	java -Xmx16G -jar ${PICARD} MergeBamAlignment \
	ALIGNED_BAM=/dev/stdin \
	UNMAPPED_BAM=${SAMPLE}_unaligned.bam \
	OUTPUT=${SAMPLE}_piped.bam \
	R=/group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
	CREATE_INDEX=true ADD_MATE_CIGAR=true \
	CLIP_ADAPTERS=false CLIP_OVERLAPPING_READS=true \
	INCLUDE_SECONDARY_ALIGNMENTS=true MAX_INSERTIONS_OR_DELETIONS=-1 \
	PRIMARY_ALIGNMENT_STRATEGY=MostDistant ATTRIBUTES_TO_RETAIN=XS \
	TMP_DIR=/scratch/mleukam/temp;
done 
