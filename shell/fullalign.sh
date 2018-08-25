#!/bin/bash
#
# INTEGRATED ALIGNMENT AND QC PIPELINE
#
# This bash script accepts a single hg-19 aligned BAM file
# 	from the python wrapper and executes a series of steps
#	to properly format, align, and quality check the reads
#	such that the output is ready for variant calling. 
#
# The files will be passed in from the python wrapper as a sample
#   name and called ${SAMPLE}
#
# Input to the pipeline should be unaligned BAM file with complete header 
#   information including read group ID per GATK best practices.   
#   There are multiple ways to generate uBAM, either directly off the 
#   sequencer or by combining FAST-A scripts (paired or unpaired).
#   A separate script should be used to generate the uBAM.
#
# Before running this script, ensure the following pre-requisites are in place
# 	1. Reference genome (.fa) stored in /group/kline-lab/ref (GRCh38_full_plus_decoy)
#	2. BWA index of reference genome (can be made with script mlbwaindex.sh) in ref folder
#	3. Picard dictionary of reference genome (.dict) in ref folder
#	4. dpSNP database (build 151 used for this project) in ref folder (.vcf)
#	5. Standard indels (Mills and 1000G gold standard indels) in ref folder (.vcf)
#	6. 1000G Phase I germline SNPs in ref folder (.vcf)
#	7. Index files of the above three references for BQSR (.vcf)
#
# Set script to fail if any command, variable, or output fails
#
set -euo pipefail
#
# Set IFS to split only on newline and tab
#
IFS=$'\n\t'
# 
# This file will keep track of messages printed during the run
#
echo "*** run by `whoami` on `date`" > runlog.txt
#
# Load compilers
#
module load java-jdk/1.8.0_92
module load gcc/6.2.0
echo "*** compilers loaded"
#
# STEP 1: Mark Illumina adapter sequences
#
# Input: *_revertsam.bam
# Output: *_markilluminaadapters.bam
#
echo "*** step 1: starting adapter sequence marking"
java -Xmx16G -jar ${PICARD} MarkIlluminaAdapters \
	I=${SAMPLE}_revertsam.bam \
	O=${SAMPLE}_markilluminaadapters.bam \
	M=${SAMPLE}_markilluminaadapters_metrics.txt \
	TMP_DIR=/scratch/mleukam/temp/ 
echo "*** step 1: illumina adapters marked"
#
# STEP 2: Make FASTQ files for alignment
# Pipe output to BWA
# Note that t flag in bwa is set to 28 for number of cores in each Gardner node
#
# Input: *_markilluminaadapters.bam
# Output: *_piped.bam
#
echo "*** loading bwa"
module load bwa
echo "*** step 2: starting alignment"
java -Xmx16G -jar ${PICARD} SamToFastq \
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
	TMP_DIR=/scratch/mleukam/temp
echo "*** step 2: alignment completed"
#  
# STEP 3: Mark duplicate sequences
#
echo "*** step 3: marking duplicate sequences"
java -Xmx16G -jar ${PICARD} MarkDuplicates \
	INPUT=${SAMPLE}_piped.bam \
	OUTPUT=${SAMPLE}_markduplicates.bam \
	METRICS_FILE=${SAMPLE}_markduplicates_metrics.txt \
	OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
	CREATE_INDEX=true \
	TMP_DIR=/scratch/mleukam/temp
echo "*** step 3: duplicate sequences marked"
#
# Make base quality recalibration table
#
echo "*** step 4: base quality recalibration started - making BQSR table"
module load gatk/4.0.6.0
java -Xmx16G -jar ${GATK} BaseRecalibrator \
    -R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    -I ${SAMPLE}_markduplicates.bam \
   	--known-sites /group/kline-lab/ref/dbsnp_151.vcf \
    --known-sites /group/kline-lab/ref/Mills_and_1000G_gold_standard.indels.hg38.vcf \
    --known-sites /group/kline-lab/ref/1000G_phase1.snps.high_confidence.hg38.vcf \
    -O ${SAMPLE}_bqsr.table
echo "*** BQSR table complete"
#
## Apply the recalibration to the sequence data
#
echo "*** apply BQSR to BAM"
java -Xmx16G -jar ${GATK} ApplyBQSR \
	-R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    -I ${SAMPLE}_addRG.bam \
    --bqsr-recal-file ${SAMPLE}_bqsr.table \
    -O ${SAMPLE}_bqsr.bam
echo "*** step 4: base quality scores recalibrated"
echo "*** files ready for variant calling"
#
# Clean up intermediate files
#
rm ${SAMPLE}_markilluminaadapters.bam
rm 