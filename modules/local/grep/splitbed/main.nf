process GREP_SPLITBED {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/9c/9c5011b66cefc341c95f909a4aea1136ab013b8e5f3168846e002bb8a8ebda36/data' :
        'community.wave.seqera.io/library/grep:3.12--57fa90c9e9eb838c' }"

    input:
    tuple val(meta), path(bed)

    output:
    tuple val(meta), path("*.chrx.bed")     , emit: bed_chrx
    tuple val(meta), path("*.autosomal.bed"), emit: bed_autosomal
    tuple val("${task.process}"), val('grep'), eval("grep --version | head -1 | sed -e 's/grep (GNU grep) //'"), topic: versions , emit: versions_grep

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # || true prevents failure when no regions are found
    grep -v -E '^chrX|^X' $bed > ${prefix}.autosomal.bed || true
    grep -E '^chrX|^X' $bed > ${prefix}.chrx.bed || true
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.autosomal.bed
    touch ${prefix}.chrx.bed
    """
}
