# Script to convert FASTQ files to unaligned (uBAM) format
# Built specifically for WES data that was transferred 8/2/18
# Designed for batch submission to Gardner HPC at UChicago
# First line = shebang to specify interpretor (bash)
# Before using, use chmod to make executable
#
#!/bin/bash
#
# Set script to fail if any command, variable, or output fails
set -euo pipefail
#
# Set IFS to split only on newline and tab
IFS=$'\n\t'
#
# Navigate to folder containing unencrypted bam files that need hashing
cd /gpfs/data/kline-lab/EGA_redo
#
# Generate hash list and pipe to text file
md5sum *.bam > /home/mleukam/logs/unencrypted_hash.txt
#
# Naviate to folder containing encrypted bam files that need hashing
cd /gpfs/data/kline-lab/EGA_copy
#
# Generate hash list and pipe to text file
md5sum *.bam > /home/mleukam/logs/encrypted_hash.txt
#
# Print to output log
echo "hash job is done"