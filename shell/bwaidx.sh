#!/bin/bash
#
# script for indexing reference genome
# this script is not yet optimized for general use 
# this script is customized for Sravya's WGS experiment 10/2018
# intended to run on gardner HPC with PBS wrapper
# before using, make executable with chmod
#
# set script to fail if any command, variable, or output fails
set -euo pipefail
#
# set IFS to split only on newline and tab
IFS=$'\n\t' 
#
# load compilers
module load gcc/6.2.0
# 
# load module
module load bwa/0.7.17
#
# navigate to directory containing fastq files
cd /scratch/mleukam/mouse

# create bwa index files
# generate index files from reference
bwa index -a bwtsw GRCm38idx GRCm38p6_ref.fa 