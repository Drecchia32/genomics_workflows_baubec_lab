#!/bin/bash

#SBATCH --mem=10G
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --job-name=nfcore_rnaseq
#SBATCH --output=nfcore_rnaseq_%j.out
#SBATCH --error=nfcore_rnaseq_%j.err


## Activate the nextflow environment
source activate /hpc/local/CentOS7/uu_epigenetics/SOFT/miniconda3/envs/nextflow

## Make new CACHEDIR and TMPDIR for Singularity in the project dir.
## By default, these temporary dirs will be written to the compute node, but there probably isn't enough space for them there.
## Rather than putting these tmp dirs in the project dir, they could also be written to scratch or one of the global tmp dirs on the hpc.
mkdir -p ./tmp/singularity_cache
mkdir -p ./tmp/singularity_temp
export SINGULARITY_CACHEDIR=./tmp/singularity_cache
export SINGULARITY_TMPDIR=./tmp/singularity_temp


## Run nf-core rnaseq pipeline
## Can resume a run by adding the "resume"
nextflow run nf-core/rnaseq \
-r 3.12.0 \
-profile singularity \
--outdir ./nextflow_output \
-c ./resources.rnaseq.config  \
--input ./sample_sheet_xDR026.csv \
--trimmer trimgalore \
--aligner star_salmon  \
--fasta /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Sequence/WholeGenomeFasta/genome.fa \
--gtf /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Annotation/Genes/genes.gtf \
--gene_bed /hpc/shared/uu_epigenetics/davide/annotations/aws_iGenomes/references/Mus_musculus/UCSC/mm10/Annotation/Genes/genes.bed \
##-resume
