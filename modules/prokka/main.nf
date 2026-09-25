#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Annotate the assembly with Prokka: find genes and predict their functions
process PROKKA {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_single'
    conda "envs/prokka_env.yml"

    input:
    genome: Path

    // Prokka writes many files into annots/; we only pass the GFF on
    output:
    gff: Path = file("**/*.gff")

    // --prefix sets the name of every output file (genome.gff, genome.faa, ...)
    script:
    """
    prokka --cpus $task.cpus --outdir annots/ --prefix genome $genome
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    mkdir annots
    touch annots/${genome}.gff
    """


}