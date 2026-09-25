// Each process lives in its own module (modules/<name>/main.nf). `include`
// makes it available here so the workflow block below can call it.

// Modules from weeks 1 and 2
include {FASTQC} from './modules/fastqc'
include {FILTLONGER} from './modules/filtlonger'
include {FLYE} from './modules/flye'
include {BOWTIE2_INDEX} from './modules/bowtie2_index'
include {BOWTIE2_ALIGN} from './modules/bowtie2_align'
include {SAMTOOLS_SORT} from './modules/samtools'
include {PILON} from './modules/pilon'

// These are this week's modules. QUAST is included twice: `as` gives the
// second copy a new name so the same process can be called twice below.
include {BUSCO} from './modules/busco'
include {NCBI_DATASETS} from './modules/ncbi_datasets_cli'
include {QUAST} from './modules/quast'
include {QUAST as QUAST_UNPOLISHED} from './modules/quast'
include {PROKKA} from './modules/prokka'
include {BUSCO_PLOT} from './modules/busco_plot'

workflow {
    main:

    // ------------------------------------------------------------------
    // WEEKS 1 AND 2 (already complete)
    // ------------------------------------------------------------------
    // QC the reads, assemble the long reads with Flye, then polish that
    // assembly with the short reads using Pilon. The outputs you will need
    // this week are assembly_ch (unpolished) and pilon_ch (polished).

    // Read the sample sheet (params.reads, set in nextflow.config). splitCsv
    // emits one item per row, keyed by column name, and map turns each row
    // into a record, converting the file columns to Paths with file().
    //
    // NOTE: week1.nf had an error where the long reads were never added to
    // this channel (the record only held name, short1 and short2), so
    // FILTLONGER had no long reads to filter. This version fixes that by
    // including long_reads, read from the `nano` column of the sample sheet.
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


    // ------------------------------------------------------------------
    // THIS WEEK
    // ------------------------------------------------------------------
    // Each step below is one process call. Before you write it, open the
    // module in modules/<name>/main.nf and answer three questions:
    //   1. What does its `input:` block expect (how many inputs, what type)?
    //   2. Which channel above (or which param) already holds that data?
    //   3. What does its `output:` block produce, and who needs it next?
    //
    // A process call looks like:  my_out_ch = PROCESS_NAME(input_ch1, input_ch2)
    // Inputs are passed in the same order they are listed in `input:`.
    //
    // Check your wiring after every step with:  nextflow run week3.nf -stub
    // ------------------------------------------------------------------

    // Annotate the polished assembly using Prokka
    //   - You write this module yourself in modules/prokka/main.nf
    //   - Input: a single genome FASTA (Path), just like BUSCO and QUAST
    //   - Hint: which process above produced the *polished* assembly?
    // prokka_ch = PROKKA( ??? )



    // Run BUSCO on the Polished Assembly
    //   - Input: one genome FASTA (Path)
    //   - Output: a directory named BUSCO_<genome basename>, which BUSCO_PLOT
    //     will need at the end
    // busco_ch = BUSCO( ??? )


    // Download the canonical reference genome 
    //   - Input: a String accession, not a file. Look in nextflow.config for
    //     the param that holds it (you refer to params with params.<name>)
    //   - Output: the reference genome .fna file
    //   - You only download the reference once; the same output can be
    //     passed to both QUAST calls below
    // ref_ch = NCBI_DATASETS( ??? )


    // Run QUAST comparing the final assembly with the reference genome
    //   - Two inputs, in this order: (genome, ref_genome)
    //   - genome should be the *polished* assembly
    // quast_ch = QUAST( ???, ??? )


    // Run QUAST on the unpolished assembly
    //   - Same process as above, imported under a second name so Nextflow
    //     lets you call it twice (a process can only be called once per name)
    //   - genome should be the *unpolished* assembly: which process produced
    //     the assembly before Pilon polished it?
    // quast_unpolished_ch = QUAST_UNPOLISHED( ???, ??? )


    // Run BUSCO PLOT on the BUSCO output
    //   - Input: the BUSCO results directory (a Path)
    // busco_plot_ch = BUSCO_PLOT( ??? )


    publish:
    quast_out = quast_ch
    quast_unpolished_out = quast_unpolished_ch
    busco_plot_out = busco_plot_ch

}

output {

    quast_out {
        path {"quast_polished/"}
    }

    quast_unpolished_out {
        path {"quast_unpolished/"}
    }

    busco_plot_out {
        path {"busco/"}
    }


}