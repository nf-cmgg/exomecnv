process PATHFILE {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/coreutils:9.3' :
        'biocontainers/coreutils:9.3' }"

    publishDir "$params.outdir/clincnv/counts/$meta.id", mode: 'copy'

    input:
    tuple val(meta), val(samples), path(files)

    output:
    tuple val(meta), val(samples), path("*.txt"), emit: counts

    script:
    def prefix = task.ext.prefix ?: "${meta.id}_paths"
    def publishDir = "$params.outdir/clincnv/counts/$meta.id"
    def fileList = files.collect(file -> "${publishDir}/${file}").join('\n')
    """
    echo -e "${fileList}" > ${prefix}.txt
    """
}
