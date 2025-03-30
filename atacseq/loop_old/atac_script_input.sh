# Activate the Conda environment
source activate /hpc/local/CentOS7/uu_epigenetics/SOFT/miniconda3/envs/DR_chip

# Record the start time of the overall script
start_time=$(date +"%Y-%m-%d %H:%M:%S")


#-------------------------------\
echo "This script will align single-ended data, filter by MAPQ, filter blacklisted regions, remove duplicates, 
Input 1 = Fastq file
Input 2 = Number of cores to use
Input 3 = Project directory
"

# Initialize variable for input fastq file
fq=$1

# Set number of cores to be used, as definedd when script is called
CORES=$2

# Set project path 
PROJECTPATH=$3

# Grab base of filename for naming outputs
base=`basename $fq`
echo "Sample name is $base"


### Overview
# 1) Trims reads
# 2) Align with bowtie2
# 3) Convert sam to bam
# 4) Sort bam
# 5) Filter by MAPQ
# 6) Filtering blacklisted regions
# 7) Remove duplicates
# 8) Calculate CPM coverage

echo "trimming with trim_galore"
# Single-end trimming with trim_galore
trim_galore --quality 20 --cores $((CORES)) --gzip --output_dir $PROJECTPATH/trimmed ${fq%R1.fastq.gz}R1.fastq.gz


echo "aligning with bowtie2"
# Map with bowtie2
bowtie2 -x /hpc/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Sequence/Bowtie2Index/genome -p $((CORES)) -U $PROJECTPATH/trimmed/${base%R1.fastq.gz}R1_trimmed.fq.gz -S $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.sam &> $PROJECTPATH/mapped/${base%R1.fastq.gz}.bt2.mm10.report.txt


echo "converting sam to bam"
# Samtools to convert sam to bam
samtools view -b -@ $((CORES)) $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.sam > $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.bam 
rm $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.sam


echo "Sorting Bam" 
# Samtools to sort the newly made bam file
samtools sort -@ 8 -m 4G $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.bam -o $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.bam
rm $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.bam 


echo "filtering by MAPQ"
# Filter by MAPQ score 
samtools view -b -@ $((CORES)) -q 40 $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.bam > $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.bam
rm $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.bam


echo "filtering blacklisted regions"
# Removing blacklisted regions from bam
bedtools intersect -v -abam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.bam -b /hpc/uu_epigenetics/davide/annotations/blacklists/mm10-blacklist.v2.bed > $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.bam
rm $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.bam


echo "removing duplicates"
# Removing duplicates
sambamba markdup --remove-duplicates $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.bam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.nodup.bam
rm $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.bam


#bamcoverage was having issues makign bigwig files for these very large bam files, since it didn't have enough space in the defaule TMPDIR on the compute nodes scratch. 
#as a quick fix, I just made a temporary TMPDIR. this could also be on the head nodes tmp dir
TMPDIR='/hpc/uu_epigenetics/davide/atac_seq/stefans_data/manual_analysis/tmp_dir_temporary_fix'
export TMPDIR


# Calculating CPM coverage with bamCoverage. This will calculate covereage over several different bin sizes, depending on what is needed.
echo "calculating coverage with bamCoverage: Bigwig"
# Coverage over 1bp windows
bamCoverage --bam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.nodup.bam -o $PROJECTPATH/bigwig/${base%R1.fastq.gz}bt2.mm10.CPM.1bpBin.bw --binSize 1 --normalizeUsing CPM --effectiveGenomeSize 2467481008 --ignoreForNormalization chrX chrY chrM --skipNAs --numberOfProcessors $((CORES))
# Coverage over 100bp windows
bamCoverage --bam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.nodup.bam -o $PROJECTPATH/bigwig/${base%R1.fastq.gz}bt2.mm10.CPM.100bpBin.bw --binSize 100 --normalizeUsing CPM --effectiveGenomeSize 2467481008 --ignoreForNormalization chrX chrY chrM --skipNAs --numberOfProcessors $((CORES))
# Coverage over 1kb windows
bamCoverage --bam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.nodup.bam -o $PROJECTPATH/bigwig/${base%R1.fastq.gz}bt2.mm10.CPM.1kbBin.bw --binSize 1000 --normalizeUsing CPM --effectiveGenomeSize 2467481008 --ignoreForNormalization chrX chrY chrM --skipNAs --numberOfProcessors $((CORES))
# Coverage over 10kb windows
bamCoverage --bam $PROJECTPATH/mapped/${base%R1.fastq.gz}bt2.mm10.s.q40.blacklistFiltered.nodup.bam -o $PROJECTPATH/bigwig/${base%R1.fastq.gz}bt2.mm10.CPM.10kbBin.bw --binSize 10000 --normalizeUsing CPM --effectiveGenomeSize 2467481008 --ignoreForNormalization chrX chrY chrM --skipNAs --numberOfProcessors $((CORES))

## List of genome sizes by reads size
# Effective genome size mm10 50bp: 2308125299
# Effective genome size mm10 75bp: 2407883243
# Effective genome size mm10 100bp: 2467481008



echo "Analysis complete!"




# Record the end time of the overall script
end_time=$(date +"%Y-%m-%d %H:%M:%S")

# Calculate the total run time of the script
total_run_time=$(($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)))

# Print the total run time to a separate file
echo "Total Run Time: $total_run_time seconds"
echo "Total number of cores used per: $((CORES))"



