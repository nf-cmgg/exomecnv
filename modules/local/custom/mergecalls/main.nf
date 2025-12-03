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
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    header=\$(head -1 ${files[0]})
    echo "\$header" >> ${prefix}.txt

    cat $files | { grep -v "\$header" || :; } | LC_ALL=C sort -k7,7V -k5,5n -k6,6n >> ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | sed '1!d; s/cat (GNU coreutils) //')
        grep: \$(grep 2>&1 | head -1 | sed 's/BusyBox v//;s/ (.*//')
        sort: \$(sort --version | sed '1!d; s/sort (GNU coreutils) //')
        head: \$(head --version | sed '1!d; s/head (GNU coreutils) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cat: \$(cat --version | sed '1!d; s/cat (GNU coreutils) //')
        grep: \$(grep 2>&1 | head -1 | sed 's/BusyBox v//;s/ (.*//')
        sort: \$(sort --version | sed '1!d; s/sort (GNU coreutils) //')
        head: \$(head --version | sed '1!d; s/head (GNU coreutils) //')
    END_VERSIONS
    """
}
