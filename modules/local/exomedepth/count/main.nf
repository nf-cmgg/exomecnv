process EXOMEDEPTH_COUNT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.16--r43hfb3cda0_3' :
        'biocontainers/r-exomedepth:1.1.16--r43hfb3cda0_3' }"

    input:
    tuple val(meta), path(bam), path(bai), val(sample)
    tuple val(meta2), path(exon_target)
    val(chromosome)

    output:
    tuple val(meta), path("*.txt"), emit: counts
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-cmgg/exomecnv/bin/

    def VERSION = '1.1.16'

    """
    ExomeDepth_count.R \\
        $sample \\
        $bam \\
        $bai \\
        $exon_target \\
        $chromosome

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS

    """

    stub:
    def VERSION = '1.1.16'
    """
    touch ${sample}_${chromosome}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """
}
