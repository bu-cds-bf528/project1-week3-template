#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Must match the record SAMTOOLS_SORT emits: sorted BAM + index
record BamIdx {
    name: String
    bam: Path
    idx: Path

}

// Polish the assembly with Pilon: it uses the short-read alignments to fix
// small errors (SNPs, small indels) left over from the long-read assembly
process PILON {

    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_high'
    conda 'envs/pilon_env.yml'

    // Needs both the original assembly and the reads aligned to it
    input:
    assembly: Path
    bamidx: BamIdx
    
    output:
    improved: Path = file('pilon.fasta')

    // Pilon is a Java program; -Xmx32G sets the maximum memory the JVM can use.
    // bamidx.idx isn't named in the command, but because it is part of the
    // input record it is staged next to the BAM, where Pilon looks for it.
    script:
    """ 
    pilon --genome $assembly --frags $bamidx.bam -Xmx32G
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    touch pilon.fasta
    """

}