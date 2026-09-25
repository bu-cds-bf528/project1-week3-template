#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Each module declares the records it uses so it can be included on its own.

// A single FASTQ file tagged with the sample it came from
record FastqRead {
    name: String
    read: Path
}

// The two files FastQC produces for each FASTQ it is given
record FastqcReport {
    html: Path
    zip: Path
}


// Run FastQC on one FASTQ file to produce a read quality report
process FASTQC {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_single'
    conda 'envs/fastqc_env.yml'

    input:
    reads: FastqRead

    // file() with a glob matches the files FastQC writes into the work
    // directory; wrapping them in a record lets downstream steps use
    // report.html or report.zip by name
    output:
    report: FastqcReport = record(html: file("*_fastqc.html"), zip: file("*_fastqc.zip"))

    script:
    """
    fastqc $reads.read
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch ${reads.read.baseName}_stub_fastqc.html
    touch ${reads.read.baseName}_stub_fastqc.zip
    """

}