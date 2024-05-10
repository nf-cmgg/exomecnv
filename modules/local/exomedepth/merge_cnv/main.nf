//MERGE CNV CALL FILES
process CNV_MERGE {
    tag "$meta"

    container "quay.io/biocontainers/coreutils:9.3"
    conda "${moduleDir}/environment.yml"

    publishDir "$params.outdir/exomedepth/cnv_call", mode: 'copy'

    input:
    tuple val(meta), path(auto), path(chrx)

    output:
    tuple val(meta), path("*.txt"), emit:merge
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta}_CNVs_ExomeDepth"
    """
    cp $auto "${prefix}.txt"
    tail +2 $chrx >> "${prefix}.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tail:\$(tail --version | sed '1!d; s/tail//')
        cp:\$(cp --version | sed '1!d; s/cp//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta}_CNVs_ExomeDepth"
    """
    touch ${prefix}.txt
    """
}
