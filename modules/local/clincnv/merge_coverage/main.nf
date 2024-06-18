// MERGE COUNT FILES
process COVERAGE_MERGE {
    tag "$meta.id"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cmgg/clincnv:1.18.3':
        'cmgg/clincnv:1.18.3' }"
    conda "${moduleDir}/environment.yml"

    publishDir "$params.outdir/clincnv/counts/$meta.id", mode: 'copy'

    input:
    tuple val(meta), val(samples), path(file)

    output:
    tuple val(meta), val(samples), path("*.txt"), emit: merge
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}.normal"
    def args = task.ext.args ?: ''
    def VERSION = '1.19.0'
    """
    mergeFilesFromFolderDT.R \\
        -i ${file} \\
        -o ${prefix}.txt \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ClinCNV: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.19.0'
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ClinCNV: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """
}
