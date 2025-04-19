#!/bin/bash
#SBATCH --job-name=cutnrun-array
#SBATCH --output=%A_%a.out
#SBATCH --error=%A_%a.err
#SBATCH --array=0-1            # Replace <N-1> with number of samples - 1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16 #change back to 16 later!
#SBATCH --time=0-16:00
#SBATCH --mem=32G
#SBATCH --gres=tmpspace:20G

# Activate the Conda environment
source activate /hpc/uu_epigenetics/software/scripts/soft/miniconda3/envs/DR_chip


#Define input 
# Set path to config file (containing only file names, not paths). This shold be a txt file with the first column listing the R1 reads. R2 reads will be inferred from their names
CONFIG_FILE="/hpc/uu_epigenetics/software/scripts/cutnrun/scripts_merge/array/config.txt"

# Set path to directory containing FASTQ files. Dir info should not be in config file
FASTQDIR="/hpc/uu_epigenetics/software/scripts/cutnrun/analyzed/merged/fasta"  # <== update this as needed

# Set number of threads
CORES=16  # Adjust when scaling up



#Define output dir
# Set project path to current working directory
PROJECTPATH="/hpc/uu_epigenetics/software/scripts/cutnrun/scripts_merge/array"

# Make output directories
mkdir -p $PROJECTPATH/sbatch_output
mkdir -p $PROJECTPATH/trimmed
mkdir -p $PROJECTPATH/mapped
mkdir -p $PROJECTPATH/mapped/bed
mkdir -p $PROJECTPATH/mapped/stats
mkdir -p $PROJECTPATH/bedgraph
mkdir -p $PROJECTPATH/bigwig
mkdir -p $PROJECTPATH/package_versions_conda


# Get FASTQ file (R1) from config and build full path
fq_name=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" "$CONFIG_FILE")
fq="$FASTQDIR/$fq_name"


# grab base of filename for naming outputs
base=`basename $fq`

echo "== SLURM Job ID: $SLURM_ARRAY_TASK_ID =="
echo "fq (R1) file: $fq"
echo "Sample base name: $base"

# Example command: Trim Galore (edit for your actual pipeline)
#trim_galore --paired "$fq1" "$fq2" --cores "$CORES" --output_dir trimmed_output
#trim_galore --quality 20 --cores $((CORES)) --gzip --output_dir $PROJECTPATH/trimmed ${fq%R1.fastq.gz}R1.fastq.gz
trim_galore --paired --quality 20 --cores $((CORES)) --gzip --output_dir $PROJECTPATH/trimmed ${fq%R1_001.fastq.gz}R1_001.fastq.gz ${fq%R1_001.fastq.gz}R2_001.fastq.gz



echo "aligning with bowtie2"
#map with bowtie2
bowtie2 --local --very-sensitive --no-mixed --no-discordant --phred33 -I 10 -X 700 -p $((CORES)) -x /hpc/uu_epigenetics/software/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Sequence/Bowtie2Index/genome -1 $PROJECTPATH/trimmed/${base%R1_001.fastq.gz}R1_001_val_1.fq.gz -2 $PROJECTPATH/trimmed/${base%R1_001.fastq.gz}R2_001_val_2.fq.gz -S $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.sam &> $PROJECTPATH/mapped/${base%R1_001.fastq.gz}.bt2.mm10.report.txt

#removing trimmed reads after mapping them
rm $PROJECTPATH/trimmed/${base%R1_001.fastq.gz}R1_001_val_1.fq.gz
rm $PROJECTPATH/trimmed/${base%R1_001.fastq.gz}R2_001_val_2.fq.gz


echo "converting sam to bam"
#convert sam to bam
#samtools to extract only the read-pairs that were mapped to the genome
#MAPQ filtering -q 20 to filter read quality
# -F 0x04 : exclude unmapped reads
# -f 0x01 : keep only reads in a pair; not in use now
# -f 0x02 : keep only reads in a pair where both reads are properly mapped
samtools view -b -f 0x02 -F 0x04 -q 20 -@ $((CORES)) $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.sam >$PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam 
rm $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.sam

#flagstat after initial mapping
samtools flagstat $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam > $PROJECTPATH/mapped/stats/${base%R1_001.fastq.gz}initial_mapping_stats.txt


echo "blacklist filtering"
#removing blacklisted regions from bam
bedtools intersect -v -abam $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam -b /hpc/uu_epigenetics/software/annotations/mm10-blacklist_with_chrM.v2.bed > $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.blacklistFiltered.bam
rm $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam 

#new blacklist with mito genome: /hpc/uu_epigenetics/davide/annotations/blacklists/mm10_mitochondrial_blacklist/mm10-blacklist_with_chrM.v2.bed
#old blacklist: /hpc/uu_epigenetics/davide/annotations/blacklists/mm10-blacklist.v2.bed



echo "final filtering for paired end read-pairs"
#re-filtering for paired end read-pairs. Has to be done after bedtools intersect, because if one of the paired end reads is removed in the blacklisted region, the other read should also be removed.
#-F 0x04: Exclude unmapped reads, probably unecessary since this was done above
# -f 0x02 : keep only reads in a pair where both reads are properly mapped
samtools view -b -f 0x02 -F 0x04 -@ $((CORES)) $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.blacklistFiltered.bam >$PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam 
rm $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.blacklistFiltered.bam

#flagstat after all filtering
samtools flagstat $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam > $PROJECTPATH/mapped/stats/${base%R1_001.fastq.gz}final_stats.txt


###this is where I could look at read duplication with picard/samtools. Only necessary if libraries have large amount of duplicate reads
#after de-dupliocation, I'd have to re-fiter for paired end reads where both reads are mapped with samtools:samtools view -b -f 0x02


#format conversion to extract paired-end reads that have a fragment length <1000bp.
echo "file format conversion"

## Convert into bed file format
bedtools bamtobed -i $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam -bedpe >$PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.mapped.bed

##keep read pairs that are on the same chromosome and that have a fragment length less than 1000bp.
awk '$1==$4 && $6-$2 < 1000 {print $0}' $PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.mapped.bed >$PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.mapped.clean.bed

##extract only the the fragment related columns
cut -f 1,2,6 $PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.mapped.clean.bed | sort -k1,1 -k2,2n -k3,3n  >$PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.fragments.bed
rm $PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.mapped.clean.bed


#could sort and index bam files if necessayr. Im leaving it out for now
#sorting and indexing bam file to ultimately get the scaling factor
#samtools sort -@ $((CORES)) $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam -o $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.sorted.bam
#samtools index -@ $((CORES)) $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.sorted.bam


#calculate scaling factor by dividing an arbitrarily large number by the number of mapped reads
ScalingFactor=$(bc <<< "scale=6;1000000/$(samtools view -f 0 -c $PROJECTPATH/mapped/${base%R1_001.fastq.gz}bt2.mm10.mapped.bam)")

#save scaling factor to a text file for later use
echo $ScalingFactor > $PROJECTPATH/bedgraph/${base%R1_001.fastq.gz}ScalingFactor.txt

##CPM scaling
#generate a bedgraph file and apply the scaling factor
#apply scaling factor:
bedtools genomecov -bg -scale $ScalingFactor -i $PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.fragments.bed -g /hpc/uu_epigenetics/software/annotations/mm10.chrom.sizes > $PROJECTPATH/bedgraph/${base%R1_001.fastq.gz}bt2.mm10.fragments.manualCPM.bedgraph

#convert from bedgraaph to bigWig
#bigwig is normalized, becaause the bedgraph file was normalized in the last step
bedGraphToBigWig $PROJECTPATH/bedgraph/${base%R1_001.fastq.gz}bt2.mm10.fragments.manualCPM.bedgraph /hpc/uu_epigenetics/software/annotations/mm10.chrom.sizes $PROJECTPATH/bigwig/${base%R1_001.fastq.gz}bt2.mm10.fragments.manualCPM.bigwig


##unscaled
#unscaled begraph
bedtools genomecov -bg -scale 1.0 -i $PROJECTPATH/mapped/bed/${base%R1_001.fastq.gz}bt2.mm10.fragments.bed -g /hpc/uu_epigenetics/software/annotations/mm10.chrom.sizes > $PROJECTPATH/bedgraph/${base%R1_001.fastq.gz}bt2.mm10.fragments.unscaled.bedgraph

#unscaled bigwig
bedGraphToBigWig $PROJECTPATH/bedgraph/${base%R1_001.fastq.gz}bt2.mm10.fragments.unscaled.bedgraph /hpc/uu_epigenetics/software/annotations/mm10.chrom.sizes $PROJECTPATH/bigwig/${base%R1_001.fastq.gz}bt2.mm10.fragments.unscaled.bigwig




#Record the end time of the overall script
end_time=$(date +"%Y-%m-%d %H:%M:%S")

#valculate the total run time of the script
total_run_time=$(($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s)))

#print the total run time to a separate file
echo "Total Run Time: $total_run_time seconds"
echo "Total number of cores used per: $((CORES))"

