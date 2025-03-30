#! /bin/bash


CORES=8

## Specify the dir where all of the fast.gz files are located
INPUT_DIR="" # modify dir OR change to $1

## Specify the dir where the output will be saved
PROJECTPATH="" #modify dir OR change to $2


#-------------------------------\
echo "This script will initiate a single-end atac-seq analysis by looping over all fastq.gz files in a specified dir.
To run, m
Input 1 = Location of fastq.gz files
Input 2 = Path for the output
"



# Make output directories
mkdir -p $PROJECTPATH/sbatch_output
mkdir -p $PROJECTPATH/trimmed
mkdir -p $PROJECTPATH/mapped
mkdir -p $PROJECTPATH/mapped/bed
mkdir -p $PROJECTPATH/mapped/stats
mkdir -p $PROJECTPATH/bedgraph
mkdir -p $PROJECTPATH/bigwig
mkdir -p $PROJECTPATH/package_versions_conda


# Loop over fastq.gz file to submit them to analysis script
for fq in $INPUT_DIR/*R1.fastq.gz
do

## Set default time for maximum 5 hours
## Define number of cores in for each analysis
## Define job name
## Make an output and error file for each sample
## Run analysis script for each fastq.gz file, with the specified cores, and the specified project dir
sbatch -t 0-5:00 -n $((CORES)) --job-name atacseq-analysis -o $PROJECTPATH/sbatch_output/%j.out -e $PROJECTPATH/sbatch_output/%j.err \
--wrap="/hpc/uu_epigenetics/davide/atac_seq/stefans_data/manual_analysis/atac_script_input.sh $fq $((CORES)) $PROJECTPATH"

## Wait 1 second inbetween each job submission
sleep 1

done



## Export info in the conda environment used
source activate /hpc/local/CentOS7/uu_epigenetics/SOFT/miniconda3/envs/DR_chip
conda list --explicit > $PROJECTPATH/package_versions_conda/conda_environment_info.txt

