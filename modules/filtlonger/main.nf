#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Each module declares the records it uses so it can be included on its own.

// A single FASTQ file tagged with the sample it came from
record FastqRead {
    name: String
    read: Path
}

// Everything we know about one sample: long reads plus paired short reads
record AssemblyReads {
    name: String
    long_reads: Path
    short1: Path
    short2: Path
}

// Filter the long reads with Filtlong: drop reads shorter than 500 bp and
// keep the best 90% of bases, giving Flye a cleaner input to assemble
process FILTLONGER {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_single'
    conda 'envs/filtlong_env.yml'

    input:
    reads: AssemblyReads

    // Keep the sample name attached to the filtered reads so the next step
    // knows which sample it is working on
    output:
    filtered: FastqRead = record(name: reads.name, read: file("${reads.name}.filtered.fastq.gz"))

    // Filtlong writes to stdout, so we pipe it through gzip to compress it
    script:
    """
    filtlong --min_length 500 --keep_percent 90 $reads.long_reads | gzip > ${reads.name}.filtered.fastq.gz
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch ${reads.name}.filtered.fastq.gz
    """

}