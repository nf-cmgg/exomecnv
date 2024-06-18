process BEDCOVERAGE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ngs-bits:2023_02--py311ha0b7adc_2' :
        'biocontainers/ngs-bits:2023_02--py311ha0b7adc_2' }"

    publishDir "$params.outdir/clincnv/counts/$meta.pool", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(exon_target)

    output:
    tuple val(meta), path("*.cov"), emit: counts
    path "versions.yml", emit:versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    BedCoverage \\
        -bam $bam \\
        -in $exon_target \\
        $args \\
        -threads $task.cpus \\
        -out ${meta.id}.cov

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        BedCoverage: \$(BedCoverage --version | sed 's/BedCoverage //g')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.cov

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        BedCoverage: \$(BedCoverage --version | sed 's/BedCoverage //g')
    END_VERSIONS
    """
}
