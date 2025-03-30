#!/bin/bash

#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --job-name=nfcore_rnaseq
#SBATCH --output=nfcore_rnaseq_%j.out
#SBATCH --error=nfcore_rnaseq_%j.err


##don't always have to initialize conda
## Initialize conda
source /hpc/local/CentOS7/uu_epigenetics/SOFT/miniconda3/etc/profile.d/conda.sh

## Activate the nextflow environment
conda activate /hpc/local/CentOS7/uu_epigenetics/SOFT/miniconda3/envs/nextflow


##the cache was getting full, and wass using my home directory as the cache. I'm changing this to use some directory in the working dir. This will have to be deleted later!
mkdir -p /hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_cache
mkdir -p /hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_temp
export SINGULARITY_CACHEDIR=/hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_cache
export SINGULARITY_TMPDIR=/hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_temp

##this is a temporyr fix. thi scan be made permanent by updating my bashrc:
##echo "export SINGULARITY_CACHEDIR=/hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_cache" >> ~/.bashrc
##echo "export SINGULARITY_TMPDIR=/hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/tmp/singularity_temp" >> ~/.bashrc
##I wont update this yet, instead I'll wait until I know where to save the temporary files in the scratch.
##this tmp directory should be manually cleaned when the job is finished running

nextflow run nf-core/rnaseq \
-r 3.12.0 \
-profile singularity \
--outdir /hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/nextflow_output \
-c /hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/resources.rnaseq.config  \
--input /hpc/shared/uu_epigenetics/davide/rna_seq/xDR026/sample_sheet_xDR026.csv \
--trimmer trimgalore \
--aligner star_salmon  \
--fasta /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Sequence/WholeGenomeFasta/genome.fa \
--gtf /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Annotation/Genes/genes.gtf \
--gene_bed /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Annotation/Genes/genes.bed \
##-resume
