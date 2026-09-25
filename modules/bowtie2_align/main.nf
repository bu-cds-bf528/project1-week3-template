#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Each module declares the records it uses so it can be included on its own.

// The paired short reads for one sample
record ShortReads {
    name: String
    short1: Path
    short2: Path
}

// An unsorted alignment for one sample
record BamRec {
    name: String
    bam: Path
}

// Must match the record BOWTIE2_INDEX emits: index prefix + directory
record BowtieIndex {
    name: String
    index: Path
}

// Align the paired short reads to the assembly with bowtie2
process BOWTIE2_ALIGN {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_high'
    conda 'envs/bowtie2_env.yml'

    // Two inputs, passed in this order when the process is called
    input:
    reads: ShortReads
    idx: BowtieIndex

    output:
    bam: BamRec = record(name: reads.name, bam: file("${reads.name}.bam"))

    // bowtie2 writes SAM to stdout; samtools view -bS converts it to the
    // smaller binary BAM format on the fly without writing a SAM to disk
    script:
    """ 
    bowtie2 -x bowtie2_index/${idx.name} -1 ${reads.short1} -2 ${reads.short2} | samtools view -bS - > ${reads.name}.bam
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch ${reads.name}.bam
    """

}