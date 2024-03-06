process EXOMEDEPTH_COUNT {
    tag "$meta.id $prefix"
    label 'process_low'

    conda "conda-forge::r=3.6"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.12--r36h6786f55_0' :
        'biocontainers/r-exomedepth:1.1.12--r36h6786f55_0' }"

    input:
    tuple val(meta), path(bam), path(bai)
    tuple val(prefix), path(exon_target)

    output:
    path '*.txt'       , emit: counts
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: // This script is bundled with the pipeline, in nf-cmgg/exomecnv/bin/
    
    def VERSION = '1.1.12'
    
    """
    Rscript CNV_ExomeDepth_counting.R

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS

    """
}
