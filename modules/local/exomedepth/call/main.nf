process EXOMEDEPTH_CALL {
    tag "$sample"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.18--r44hb2a3317_0' :
        'quay.io/biocontainers/r-exomedepth:1.1.18--r44hb2a3317_0' }"

    input:
    tuple val(meta), path(countfile), val(sample), val(samples), val(families), path(exon_target)

    output:
    tuple val(meta), path("*.txt"), emit: cnvcall
    tuple val("${task.process}"), val('ExomeDepth'), val('1.1.18'), topic: versions, emit: versions_exomedepth
    tuple val("${task.process}"), val('R'), eval("Rscript --version 2>&1 | cut -d' ' -f4"), topic: versions, emit: versions_r

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ExomeDepth_cnv_calling.R \\
        $sample \\
        $countfile \\
        $exon_target \\
        $prefix \\
        $samples \\
        $families
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt
    """
}
