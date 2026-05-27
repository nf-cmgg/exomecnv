process CUSTOM_MERGECALLS {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c262fc09eca59edb5a724080eeceb00fb06396f510aefb229c2d2c6897e63975/data' :
        'community.wave.seqera.io/library/coreutils:9.5--ae99c88a9b28c264' }"
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("*.txt"), emit:merge
    tuple val("${task.process}"), val('cat'), eval("cat --version | sed '1!d; s/cat (GNU coreutils) //'"), topic: versions , emit: versions_cat
    tuple val("${task.process}"), val('grep'), eval("grep --version 2>&1 | head -n 1 | sed '1!d; s/grep (GNU grep) //'"), topic: versions , emit: versions_grep
    tuple val("${task.process}"), val('sort'), eval("sort --version | sed '1!d; s/sort (GNU coreutils) //'"), topic: versions , emit: versions_sort
    tuple val("${task.process}"), val('head'), eval("head --version | sed '1!d; s/head (GNU coreutils) //'"), topic: versions , emit: versions_head

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    header=\$(head -1 ${files[0]})
    echo "\$header" >> ${prefix}.txt

    cat $files | { grep -v "\$header" || :; } | LC_ALL=C sort -k7,7V -k5,5n -k6,6n >> ${prefix}.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt
    """
}
