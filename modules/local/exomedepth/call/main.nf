process EXOMEDEPTH_CALL {
    tag "$sample"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.16--r43hfb3cda0_3' :
        'biocontainers/r-exomedepth:1.1.16--r43hfb3cda0_3' }"

    input:
    tuple val(meta), path(countfile), val(sample), val(samples), val(families) // meta:id, chr, sam, fam, sample
    tuple val(meta2), path(exon_target) // meta.id=chrx/autosomal

    output:
    tuple val(meta), path("*.txt"), emit: cnvcall
    path "versions.yml", emit:versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.1.16'

    """
    ExomeDepth_cnv_calling.R \\
        $sample \\
        $countfile \\
        $exon_target \\
        $prefix \\
        $samples \\
        $families

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.1.16'
    """
    touch ${prefix}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """
}
