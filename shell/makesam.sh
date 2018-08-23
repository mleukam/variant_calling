#working loop for converting BAMs without EOF tag to SAMs
#needs to be fleshed out to be working script

for file in ./*.bam; 
do 
	echo $file; 
	samtools view -h $file > ${file/.bam/.sam}; 
done
