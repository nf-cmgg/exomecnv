//REFORMAT SAMTOOLS BEDCOV FILES (add header and remove 5th column)
process CUSTOM_REFORMATCOUNTS {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'biocontainers/coreutils:9.3' }"
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("*.txt"), emit:header
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def unzipped_tsv = tsv.toString().replaceAll('\\.gz$', '')
    """
    # Only decompress if the file ends with .gz
    if [[ "$tsv" == *.gz ]]; then
        gzip -d -f $tsv
    fi

    { echo -e "chromosome\\tstart\\tend\\texon\\t${meta.id}"; \
    cut --complement -f6 $unzipped_tsv ; } > "${prefix}.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        echo: \$(echo --version | sed '1!d; s/echo (GNU coreutils) //')
        cut: \$(cut --version | sed '1!d; s/cut (GNU coreutils) //')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        echo: \$(echo --version | sed '1!d; s/echo (GNU coreutils) //')
        cut: \$(cp --version | sed '1!d; s/cut (GNU coreutils) //')
    END_VERSIONS
    """
}
