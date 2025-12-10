process CUSTOM_MERGECALLS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'biocontainers/coreutils:9.3' }"

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("*.txt"), emit:merge
    tuple val("${task.process}"), val('cat'), eval("cat --version | sed '1!d; s/cat (GNU coreutils) //'"), topic: versions , emit: versions_cat
    tuple val("${task.process}"), val('grep'), eval("grep 2>&1 | head -1 | sed 's/BusyBox v//;s/ (.*//'"), topic: versions , emit: versions_grep
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
