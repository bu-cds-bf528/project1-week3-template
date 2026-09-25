#!/usr/bin/env nextflow

// Enable Nextflow's typed syntax (records and typed process inputs/outputs)
nextflow.enable.types = true

// Draw a bar chart summarising BUSCO's complete/fragmented/missing genes
process BUSCO_PLOT {
    // Uses the same environment as BUSCO, since the plot comes from busco itself
    label 'process_single'
    conda 'envs/busco_env.yml'

    // The BUSCO results directory produced by the BUSCO process
    input:
    results: Path
    
    // ** searches subdirectories too, since the plot is written inside the
    // results directory
    output:
    plot: Path = file("**/*.png")

    script:
    """ 
    busco --plot $results
    """

    // The stub block runs instead of `script` with `nextflow run -stub`. It
    // only creates placeholder files named the way the output: block expects.
    stub:
    """
    mkdir BUSCO_RESULTS
    touch BUSCO_RESULTS/plot.png
    """

}