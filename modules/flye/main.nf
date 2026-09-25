#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// A single FASTQ file tagged with the sample it came from
record FastqRead {
    name: String
    read: Path
}

// Assemble the filtered long reads into contigs with Flye
process FLYE {
    // Assembly is the most resource-hungry step, so it gets the high profile
    label 'process_high'
    conda 'envs/flye_env.yml'

    input:
    reads: FastqRead

    // A bare Path output: the channel emits just the assembly file
    output:
    fasta: Path = file("assembly.fasta")

    // --nano-hq: the reads are high-quality Oxford Nanopore data
    // -o .: write output into the task's work directory
    script:
    """
    flye --nano-hq $reads.read -o .
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch assembly.fasta
    """
}
