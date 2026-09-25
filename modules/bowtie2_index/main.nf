#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// A bowtie2 index is a set of files sharing a common prefix. We carry that
// prefix (name) alongside the directory, because bowtie2 needs the prefix,
// not the directory, to find the index.
record BowtieIndex {
    name: String
    index: Path
}


// Build a bowtie2 index from the assembly so short reads can be aligned to it
process BOWTIE2_INDEX {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_high'
    conda 'envs/bowtie2_env.yml'

    input:
    reference: Path

    // baseName strips the extension (assembly.fasta -> assembly), which is
    // the prefix bowtie2-build uses for the index files
    output:
    idx: BowtieIndex = record(name: reference.baseName, index: file("bowtie2_index/"))

    // $task.cpus is the number of cpus assigned by the process label
    script:
    """ 
    mkdir bowtie2_index
    bowtie2-build $reference bowtie2_index/${reference.baseName} --threads $task.cpus
    """
    
    // Only the directory needs to exist for the stub run to wire up correctly
    stub:
    """
    mkdir bowtie2_index
    """
}
