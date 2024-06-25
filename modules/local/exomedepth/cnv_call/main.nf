process CNV_CALL {
    tag "$sample $meta2.chr"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/r-exomedepth:1.1.16--r43hfb3cda0_3' :
        'biocontainers/r-exomedepth:1.1.16--r43hfb3cda0_3' }"

    publishDir "$params.outdir/exomedepth/cnv_call", mode: 'copy'

    input:
    tuple val(meta), path(exon_target) // meta.id=chrx/autosomal
    tuple val(meta2), val(sample), path(countfile) // meta:id, chr, sam, fam, sample

    output:
    tuple val(meta2), val (sample), path("*.txt"), emit: cnvcall
    path "versions.yml", emit:versions

    script:

    def VERSION = '1.1.16'

    """
    ExomeDepth_cnv_calling.R \\
        $sample \\
        $countfile \\
        $exon_target \\
        $meta2.chr \\
        ${meta2.sam.join(',')} \\
        ${meta2.fam.join(',')} \\

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ExomeDepth: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${sample}_CNVs_ExomeDepth_${meta2.chr}"
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
