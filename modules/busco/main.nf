#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Assess assembly completeness with BUSCO: it searches the genome for a set
// of genes expected to be present in a single copy in this lineage
process BUSCO {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_high'
    conda 'envs/busco_env.yml'

    input:
    genome: Path
    
    // BUSCO writes its results into a directory named BUSCO_<basename>
    output:
    busco: Path = file("BUSCO_pilon.fasta/")

    // -m genome: the input is a genome assembly (not transcripts or proteins)
    // -l: the lineage dataset of expected genes to search for
    script:
    """ 
    busco -i ${genome} -m genome --cpu $task.cpus -l alteromonas_odb12
    """
    
    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    mkdir BUSCO_pilon.fasta
    """
}