//MERGE CNV CALL FILES
process CNV_MERGE {
    tag "$meta"

    publishDir "$params.outdir/exomedepth/cnv_call", mode: 'copy'

    input:
    tuple val(meta), path(auto), path(chrx)

    output:
    tuple val(meta), path("*.txt")

    script:
    prefix = task.ext.prefix ?: "${meta}_CNVs_ExomeDepth"
    """
    cp $auto "${prefix}.txt"
    tail +2 $chrx >> "${prefix}.txt"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta}_CNVs_ExomeDepth"
    """
    touch ${prefix}.txt
    """
}
