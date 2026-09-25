#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Compare an assembly to a reference genome with QUAST, reporting contiguity
// (N50, number of contigs) and correctness (misassemblies, mismatches)
process QUAST {
    // `label` picks a resource profile (cpus) from nextflow.config and
    // `conda` points to the environment file that provides the tool
    label 'process_medium'
    conda 'envs/quast_env.yml'

    // Two inputs, passed in this order: (assembly, reference)
    input:
    genome: Path
    ref_genome: Path

    // Name the output directory after the assembly, so the polished and
    // unpolished runs produce distinctly named results
    output:
    quast: Path = file("${genome.baseName}/")

    script:
    """ 
    quast.py -t $task.cpus -r $ref_genome -o $genome.baseName $genome
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    mkdir ${genome.baseName}
    """

}