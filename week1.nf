#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax so we can declare records and typed
// process inputs/outputs (e.g. `reads: FastqRead`) instead of tuples.
nextflow.enable.types = true

// A record is a named bundle of values that travels through a channel as a
// single item. Accessing fields by name (reads.id, reads.long_reads) is much
// less error-prone than remembering tuple positions.

// Everything we know about one sample: its long reads (for assembly) and
// its paired short reads (for QC and, next week, polishing).
record AssemblyReads {
    id: String
    long_reads: Path
    short_reads_r1: Path
    short_reads_r2: Path
}

// A single FASTQ file tagged with the sample it came from.
record FastqRead {
    id: String
    read: Path
}

// The two files FastQC produces for each FASTQ it is given.
record FastqcReport {
    html: Path
    zip: Path
}


// Run FastQC on one FASTQ file to produce a read quality report.
process FASTQC {
    // `label` picks a resource profile (cpus/memory) defined in nextflow.config
    label 'process_single'
    // `conda` points to the environment file that provides the tool
    conda 'envs/fastqc_env.yml'

    input:
    reads: FastqRead

    // The output is built as a record so downstream steps can grab
    // report.html or report.zip by name. file() with a glob matches the
    // files FastQC writes into the task's work directory.
    output:
    report: FastqcReport = record(html: file("*_fastqc.html"), zip: file("*_fastqc.zip"))

    script:
    """
    fastqc $reads.read
    """

    // The stub block runs instead of `script` with `nextflow run -stub`.
    // It just creates empty files with the expected names so we can test
    // that the channels are wired correctly without running the real tool.
    stub:
    """
    touch ${reads.id}_stub_fastqc.html
    touch ${reads.id}_stub_fastqc.zip
    """

}

// Filter the long reads with Filtlong: drop reads shorter than 500 bp and
// keep the best 90% of bases, which gives Flye a cleaner input to assemble.
process FILTLONGER {
    label 'process_single'
    conda 'envs/filterlong_env.yml'

    input:
    reads: AssemblyReads

    // Keep the sample id attached to the filtered reads so the next step
    // knows which sample it is working on and can name its output.
    output:
    filtered: FastqRead = record(id: reads.id, read: file("${reads.id}.filtered.fastq.gz"))

    script:
    """
    filtlong --min_length 500 --keep_percent 90 $reads.read | gzip > ${reads.id}.filtered.fastq.gz
    """

    stub:
    """
    touch ${reads.id}.filtered.fastq.gz
    """

}

// Assemble the filtered long reads into contigs with Flye. `--nano-hq`
// tells Flye the reads are high-quality Oxford Nanopore data.
process FLYE {
    // Assembly is the most resource-hungry step, so it gets the high profile
    label 'process_high'
    conda 'envs/flye_env.yml'

    input:
    reads: FastqRead

    // A bare Path output: this channel will emit just the assembly file
    output:
    fasta: Path = file("${reads.id}.assembly.fasta")

    script:
    """
    flye --nano-hq $reads.read -o .
    """

    stub:
    """
    touch ${reads.id}.assembly.fasta
    """
}

workflow {

    // Read the sample sheet (params.bac_samples, set in nextflow.config).
    // splitCsv(header: true) emits one item per row, keyed by column name,
    // and map turns each row into a record with the file columns converted
    // from strings into Path objects via file().
    read_pairs_ch = channel.fromPath(params.reads).splitCsv(header: true).map { row -> record(name: row.name, long_reads: file(row.nano), short1: file(row.short1), short2: file(row.short2))}

    // FastQC takes one FASTQ at a time, so split each sample into two items
    // (R1 and R2). flatMap emits every element of the returned list as its
    // own channel item, rather than emitting the list as a single item.
    fastqc_ch = read_pairs_ch.flatMap { it -> [record(id: it.name, read: it.short1), record(id: it.name, read: it.short2)]}

    fastqc_out = FASTQC(fastqc_ch)

    // Long-read branch: filter the reads, then assemble them. Calling a
    // process returns its output channel, which we feed straight into the
    // next process.
    filtered_ch = FILTLONGER(read_pairs_ch)
    assembly_ch = FLYE(filtered_ch)


}
