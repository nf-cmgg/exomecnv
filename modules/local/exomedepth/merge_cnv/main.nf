//MERGE AND SORT (ON GENOMIC POSITION) EXOMEDEPTH CNV CALL FILES
process CNV_MERGE {
    tag "$meta"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'biocontainers/coreutils:9.3' }"
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
    { head -n 1 $auto && \
    { tail -n +2 $auto && tail -n +2 $chrx ; } | \
    sort -k7,7V -k5,5n -k6,6n ; } > "${prefix}.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        head: \$(head --version | sed '1!d; s/head (GNU coreutils) //')
        tail: \$(tail --version | sed '1!d; s/tail (GNU coreutils) //')
        sort: \$(sort --version | sed '1!d; s/sort (GNU coreutils) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta}_CNVs_ExomeDepth"
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tail: \$(tail --version | sed '1!d; s/tail (GNU coreutils) //')
        cp: \$(cp --version | sed '1!d; s/cp (GNU coreutils) //')
    END_VERSIONS
    """
}
