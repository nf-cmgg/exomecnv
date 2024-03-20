process COUNT {
    tag "$meta.id $prefix.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.16--r43hfb3cda0_3' :
        'biocontainers/r-exomedepth:1.1.16--r43hfb3cda0_3' }"

    publishDir "$params.outdir/exomedepth/counts", mode: 'copy'

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(meta2), path(exon_target)

    output:
    tuple val(meta), path("*.txt"), emit: counts
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-cmgg/exomecnv/bin/

    def VERSION = '1.1.16'

    """
    ExomeDepth_count.R \\
        $meta.id \\
        $bam \\
        $bai \\
        $exon_target \\
        $meta2.id

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS

    """
}
