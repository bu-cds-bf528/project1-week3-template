#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// An unsorted alignment for one sample (what BOWTIE2_ALIGN emits)
record BamRec {
    name: String
    bam: Path
}

// A sorted alignment plus its .bai index. Pilon needs the index next to the
// BAM, so we keep the two together in one record.
record BamIdx {
    name: String
    bam: Path
    idx: Path

}

// Sort the BAM by coordinate and index it; Pilon requires both
process SAMTOOLS_SORT {

    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_medium'
    conda 'envs/samtools_env.yml'

    input:
    aln: BamRec

    output:
    bamidx: BamIdx = record(name: aln.name, bam: file("${aln.bam.baseName}.sorted.bam"), idx: file("${aln.bam.baseName}.sorted.bam.bai"))

    script:
    """ 
    samtools sort $aln.bam > ${aln.bam.baseName}.sorted.bam
    samtools index ${aln.bam.baseName}.sorted.bam
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch ${aln.bam.baseName}.sorted.bam
    touch ${aln.bam.baseName}.sorted.bam.bai
    """

}