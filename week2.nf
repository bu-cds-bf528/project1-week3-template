#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// This week we polish the Flye assembly with the short reads:
//   assembly -> bowtie2 index -> align short reads -> sort/index BAM -> Pilon

// A bowtie2 index is a set of files that share a common prefix. We carry
// that prefix (name) alongside the directory holding the files, because
// bowtie2 needs the prefix, not the directory, to find the index.
record BowtieIndex {
    name: String
    index: Path
}

// Build a bowtie2 index from the assembly so short reads can be aligned to it.
process BOWTIE2_INDEX {
    label 'process_high'
    conda 'envs/bowtie2_env.yml'

    input:
    reference: Path

    // baseName strips the extension, e.g. sample.assembly.fasta -> sample.assembly,
    // which is the prefix bowtie2-build uses for the index files below.
    output:
    idx: BowtieIndex = record(name: reference.baseName, index: file("bowtie2_index/"))

    script:
    """
    mkdir bowtie2_index
    bowtie2-build $reference bowtie2_index/${reference.baseName}
    """

    // Only the directory needs to exist for the stub run to wire up correctly
    stub:
    """
    mkdir bowtie2_index
    """
}

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

// A sorted alignment plus its .bai index. Pilon needs the index next to the
// BAM, so we keep the two together in one record.
record BamIdx {
    name: String
    bam: Path
    idx: Path

}

// Align the paired short reads to the assembly with bowtie2.
process BOWTIE2_ALIGN {
    label 'process_high'
    conda 'envs/bowtie2_env.yml'

    // Two inputs: the process runs once for each combination of items from
    // the reads channel and the index channel.
    input:
    reads: ShortReads
    idx: BowtieIndex

    output:
    bam: BamRec = record(name: reads.name, bam: file("${reads.name}.bam"))

    // bowtie2 writes SAM to stdout; samtools view -bS converts it to the
    // smaller binary BAM format on the fly without writing a SAM to disk.
    script:
    """
    bowtie2 -x bowtie2_index/${idx.name} -1 ${reads.short1} -2 ${reads.short2} | samtools view -bS - > ${reads.name}.bam
    """

    stub:
    """
    touch ${reads.name}.bam
    """

}

// Sort the BAM by coordinate and index it; Pilon requires both.
process SAMTOOLS_SORT {

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

    stub:
    """
    touch ${aln.bam.baseName}.sorted.bam
    touch ${aln.bam.baseName}.sorted.bam.bai
    """

}

// Polish the assembly with Pilon: it uses the short-read alignments to fix
// small errors (SNPs, small indels) left over from the long-read assembly.
process PILON {

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

    stub:
    """
    touch pilon.fasta
    """

}

// Rather than copying last week's processes into this file, import them
// from their modules. Each module holds one process in its own main.nf.
include {FASTQC} from './modules/fastqc/main.nf'
include {FILTLONGER} from './modules/filtlonger/main.nf'
include {FLYE} from './modules/flye/main.nf'


workflow {

    read_pairs_ch = channel.fromPath(params.reads).splitCsv(header: true).map { row -> record(name: row.name, long_reads: file(row.nano), short1: file(row.short1), short2: file(row.short2))}

    // FastQC takes one FASTQ at a time, so split each sample into two items
    // (R1 and R2). flatMap emits each element of the list as its own item.
    fastqc_ch = read_pairs_ch.flatMap { it -> [record(name: it.name, read: it.short1), record(name: it.name, read: it.short2)]}
    
    fastqc_out = FASTQC(fastqc_ch)

    // Long reads: filter out short and low-quality reads, then assemble them.
    // assembly_ch holds the *unpolished* assembly.
    filtered_ch = FILTLONGER(read_pairs_ch)
    assembly_ch = FLYE(filtered_ch)

    // Index the assembly so the short reads can be aligned to it
    bowtie2_idx_ch = BOWTIE2_INDEX(assembly_ch)

    // BOWTIE2_ALIGN only needs the short reads, so build a record without
    // the long reads
    short_read_ch = read_pairs_ch.map { it -> record(name: it.name, short1: it.short1, short2: it.short2) }

    // Align the short reads to the assembly, then sort and index the BAM
    bowtie2_align_ch = BOWTIE2_ALIGN(short_read_ch, bowtie2_idx_ch)
    bam_sort_ch = SAMTOOLS_SORT(bowtie2_align_ch)

    // Pilon uses the short-read alignments to correct small errors in the
    // Flye assembly. pilon_ch holds the *polished* assembly.
    // Inputs are passed in the order they appear in PILON's input: block.
    pilon_ch = PILON(assembly_ch, bam_sort_ch)
}
