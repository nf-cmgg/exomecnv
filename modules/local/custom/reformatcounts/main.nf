// REFORMAT COUNT FILES
// add header + make start coordinates 1-based + remove 1nt regions
process CUSTOM_REFORMATCOUNTS {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c262fc09eca59edb5a724080eeceb00fb06396f510aefb229c2d2c6897e63975/data' :
        'community.wave.seqera.io/library/coreutils:9.5--ae99c88a9b28c264' }"
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("*.txt"), emit: header
    tuple val("${task.process}"), val('cut'), eval("cut --version | sed '1!d; s/cut (GNU coreutils) //'"), topic: versions , emit: versions_cut
    // TODO: add version checks for gzip and awk if needed

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
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.txt
    """
}
