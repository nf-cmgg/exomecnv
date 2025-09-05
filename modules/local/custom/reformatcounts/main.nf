// REFORMAT COUNT FILES
// add header + make start coordinates 1-based + remove 1nt regions
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

    # make 1-based
    awk 'BEGIN{OFS="\\t"} {\$2=\$2+1; print}' "${unzipped_tsv}" > "${prefix}.tmp.txt"

    # remove regions that are only 1 nucleotide long
    awk '(\$3-\$2)!=0' "${prefix}.tmp.txt" > "${prefix}.filtered.tmp.txt"

    { echo -e "chromosome\\tstart\\tend\\texon\\t${meta.id}"; \
    cut --complement -f6 "${prefix}.filtered.tmp.txt"; } > "${prefix}.txt"

    rm ${prefix}.tmp.txt "${prefix}.filtered.tmp.txt"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        echo: \$(/bin/echo --version | sed '1!d; s/echo (GNU coreutils) //')
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
