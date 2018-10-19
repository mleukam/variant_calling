#!/bin/bash

##########
# README #
##########

# align paried-end whole exome reads from 1000GenomeProject to make appropriately formatted panel of normals
# initially formatted as CRAM files from EBI
# CRAM files converted to BAM files already using propriatary EBI hg38 reference --> not compatible with mutect2
# convert BAM to uBAM and strip alignment information
# mark illumina adapters, align, mark duplicates, and BQSR to closely match tumor whole exome processing
# intended to run on gardner HPC with PBS wrapper
# before using, make executable with chmod

#### INPUTS
# 1. BAM files for converted whole exome CRAM files from EBI 1000 genomes project (52 files)
# 2. Reference sequence for alingment (GATK bundle compatible hg38): 
# 3. Known sites from GATK bundle
	# A. dbsnp_151.vcf
	# B. Mills_and_1000G_gold_standard.indels.hg38.vcf
	# C. 1000G_phase1.snps.high_confidence.hg38.vcf

#### OUTPUTS
# 1. ${SAMPLE}_bqsr.bam--> files ready for variant calling

#########
# SETUP #
#########

# set script to fail if any command, variable, or output fails
set -euo pipefail

# set IFS to split only on newline and tab
IFS=$'\n\t'

# load compilers
module load java-jdk/1.8.0_92
module load gcc/6.2.0
 
# load modules
# NB: the path to picard.jar is automatically generated as an environment variable when picard tool module is loaded
# location of picard.jar = ${PICARD}
module load picard/2.8.1
module load bwa/0.7.17
module load gatk/4.0.6.0

# navigate to working directory
cd /gpfs/data/kline-lab/ref/1000G_PoN

# define the input variables as an array
BAMLIST=($(ls *.bam))

# pull the sample name from the input file names and make new array
SMLIST=(${BAMLIST[*]%exome.bam})

#############
# MAKE UBAM #
#############

# revert aligned BAM to unaligned BAM
# returns unaligned BAM to the same directory
for SAMPLE in ${SMLIST[*]}; 
do
	java -Xmx32G -jar ${PICARD} RevertSam \
    I=${SAMPLE}.exome.bam \
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
    REMOVE_ALIGNMENT_INFORMATION=true \
    TMP_DIR=/scratch/mleukam/temp;
done

# add read group information to unaligned BAM
for SAMPLE in ${SMLIST[*]};
do 
    java -Xmx32G -jar ${PICARD} AddOrReplaceReadGroups \
    INPUT=${SAMPLE}_revertsam.bam \
    OUTPUT=${SAMPLE}_unaligned.bam \
    RGID=1000G \
    RGLB=library1 \
    RGPL=illumina \
    RGPU=1000G${SAMPLE} \
    RGSM=${SAMPLE} \
    SORT_ORDER=coordinate \
    CREATE_INDEX=true \
    TMP_DIR=/scratch/mleukam/temp;
done

# mark Illumina adapters
for SAMPLE in ${SMLIST[*]};
do
	java -Xmx32G -jar ${PICARD} MarkIlluminaAdapters \
	I=${SAMPLE}_unaligned.bam \
	O=${SAMPLE}_markilluminaadapters.bam \
	M=${SAMPLE}_markilluminaadapters_metrics.txt \
	TMP_DIR=/scratch/mleukam/temp;
done

# clean up
rm *_revertsam.bam
rm *_unaligned.bam

# keep *exome.bam in case anything goes wrong
# output to next section is *_markilluminaadapters.bam

###################
# ALIGN SEQUENCES #
###################

# three step pipeline
# 1. convert BAM temporarily back to fastq
# 2. pass interleaved fastq to bwa mem with GATK-compliant reference sequence
# 3. merge with unaligned BAM to restore read information and remove hard clipping
for SAMPLE in ${SMLIST[*]}; 
do 
	java -Xmx32G -jar ${PICARD} SamToFastq \
	I=${SAMPLE}_markilluminaadapters.bam \
	FASTQ=/dev/stdout \
	CLIPPING_ATTRIBUTE=XT CLIPPING_ACTION=2 INTERLEAVE=true NON_PF=true \
	TMP_DIR=/scratch/mleukam/temp | \
	bwa mem -M -t 28 -p /group/kline-lab/ref/GRCh38_full_plus_decoy.fa /dev/stdin | \
	java -Xmx32G -jar ${PICARD} MergeBamAlignment \
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

# clean up
rm *_markilluminaadapters.bam

# output to next section is *_piped.bam

###################
# MARK DUPLICATES #
###################

# mark duplicates
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

# clean up
rm *_piped.bam

########
# BQSR #
########

# use the same references as the tumor and normal pairs
# analyze patterns of covariation in the sequence dataset
# known site filters for downstream variant calling include:
# 1. dbSNP database build 151
# 2. Mills and 1000 genome project standard indels
# 3. 1000 genome project phase 1 high confidence SNPs
# All stored in /group/kline-lab/ref/

# generate bqsr table
for SAMPLE in ${SMLIST[*]};
do 
	java -Xmx32G -jar ${GATK} BaseRecalibrator \
    -R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    -I ${SAMPLE}_markduplicates.bam \
   	--known-sites /group/kline-lab/ref/dbsnp_151.vcf \
    --known-sites /group/kline-lab/ref/Mills_and_1000G_gold_standard.indels.hg38.vcf \
    --known-sites /group/kline-lab/ref/1000G_phase1.snps.high_confidence.hg38.vcf \
    -O ${SAMPLE}_bqsr.table;

# apply the recalibration to the sequence data
for SAMPLE in ${SMLIST[*]};
do 
	java -Xmx16G -jar ${GATK} ApplyBQSR \
	-R /group/kline-lab/ref/GRCh38_full_plus_decoy.fa \
    -I ${SAMPLE}_addRG.bam \
    --bqsr-recal-file ${SAMPLE}_bqsr.table \
    -O ${SAMPLE}_bqsr.bam;
 done

 # clean up
 rm *_markduplicates.bam