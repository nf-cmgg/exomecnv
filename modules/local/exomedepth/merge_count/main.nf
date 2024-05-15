// MERGE COUNT FILES
process COUNT_MERGE {
    tag "$meta.id $meta.chr"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'biocontainers/coreutils:9.3' }"
    conda "${moduleDir}/environment.yml"

    publishDir "$params.outdir/exomedepth/counts", mode: 'copy'

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path("*.txt"), emit:merge
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_${meta.chr}"
    """
    for file in $files; do
        if [ -f ${prefix}.txt ]; then
            paste ${prefix}.txt <(awk '{print \$5}' \$file) > temp_auto.txt
            mv temp_auto.txt ${prefix}.txt
            else
            cp \$file ${prefix}.txt
        fi
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        paste: \$(paste --version | sed '1!d; s/paste (GNU coreutils) //')
        mv: \$(mv --version | sed '1!d; s/mv (GNU coreutils) //')
        cp: \$(cp --version | sed '1!d; s/cp (GNU coreutils) //')
        awk: \$(awk -version 2>&1 | sed '1!d; s/(.*//')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}_${meta.chr}"
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        paste: \$(paste --version | sed '1!d; s/paste (GNU coreutils) //')
        mv: \$(mv --version | sed '1!d; s/mv (GNU coreutils) //')
        cp: \$(cp --version | sed '1!d; s/cp (GNU coreutils) //')
        awk: \$(awk -version 2>&1 | sed '1!d; s/(.*//')
    END_VERSIONS
    """
}
