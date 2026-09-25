#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Download a reference genome from NCBI with the datasets CLI
process NCBI_DATASETS {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_low'
    conda 'envs/ncbidatasets_env.yml'
    // Copy the outputs out of the work directory into params.outdir
    publishDir params.outdir, mode:'copy'

    // An accession string (e.g. params.ref_genome), not a file
    input:
    assembly: String

    // The download unzips into nested folders, so ** finds the .fna at any depth
    output:
    fna: Path = file('dataset/**/*.fna')

    script:
    """ 
    datasets download genome accession $assembly --include genome
    unzip ncbi_dataset.zip -d dataset/
    """

    // Mirror the real download's folder layout so the output glob still matches
    stub:
    """
    mkdir -p dataset/ncbi_dataset/data/${assembly}
    touch dataset/ncbi_dataset/data/${assembly}/${assembly}_genomic.fna
    """

}