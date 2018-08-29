
# load necessary packages
import os
import glob

# specify local rules not submitted as cluster jobs
localrules: all, reset, clean, make_archives

rule all:
	input:
		'{folder}/alignment_qc.tar.gz'
		'{folder}/aligned_bams.tar.gz'

rule reset:
	shell:
		'''
		rm -r alignment_qc.tar.gz aligned_bams.tar.gz
		'''

rule sample_list:
	run:
		print('These are all the sample names:'
		for sample in glob.glob('wes_data/*.exome_1tier.hg19.final.bam'):
			print(sample)

# convert source alinged hg19 bam to fastq files
# fastq folder is cleaned up at the end
rule fastq:
	input: 
		bam='{folder}/{sample}.bam'
		makefastq='makefastq.sh'
	output: 
		fq1='{folder}/fastq/{sample}_1.fq'
		fq2='{folder}/fastq/{sample}_2.fq'
	shell: 'bash {input.makefastq} {input.bam} {output.fq1} {output.fq2}'

# run fastqc reports and place in qc folder 
# qc folder is not cleaned up
rule fastqc:
	input: 
		fastqc='fastqc.sh'
		fq1='{folder}/{sample}_1.fq'
		fq2='{folder}/{sample}_2.fq'
	output: '{folder}/qc/'
	shell: 'bash {input.fastqc} {input.fq1} {input.fq2} {output}'

# strip alignment information from source hg19 bam file
# output is unaligned bam
rule ubam
	input:
		makeubam='make_ubam.sh'
		bam='{folder}/{sample}.exome_1tier.hg19.final.bam'
	output: '{folder}/ubam/{sample}_unaligned.bam'
	shell: 'bash {input.makeubam} {input.fq1} {input.fq2} {output}'

# mark Illumina sequences in unaligned BAM
# output is called BAM-XT
rule 

rule clean
	shell: 
		'''
		rm -rf {folder}/fastq {path}/ubam
		'''
