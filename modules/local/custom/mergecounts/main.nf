// MERGE COUNT FILES
process CUSTOM_MERGECOUNTS {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'quay.io/biocontainers/coreutils:9.3' }"
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("*.txt"), emit:merge
    tuple val("${task.process}"), val('paste'), eval("paste --version | sed '1!d; s/paste (GNU coreutils) //'"), topic: versions , emit: versions_paste
    tuple val("${task.process}"), val('mv'), eval("mv --version | sed '1!d; s/mv (GNU coreutils) //'"), topic: versions , emit: versions_mv
    tuple val("${task.process}"), val('cp'), eval("cp --version | sed '1!d; s/cp (GNU coreutils) //'"), topic: versions , emit: versions_cp

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # Sort
    sorted_files=\$(echo $files | tr ' ' '\\n' | sort -V | tr '\\n' ' ')
    # Remove trailing space
    sorted_files=\$(echo \$sorted_files | sed 's/ *\$//')
    for file in \$sorted_files; do
        if [ -f ${prefix}.txt ]; then
            paste ${prefix}.txt <(awk '{print \$5}' \$file) > temp_auto.txt
            mv temp_auto.txt ${prefix}.txt
            else
            cp \$file ${prefix}.txt
        fi
    done
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt
    """
}
