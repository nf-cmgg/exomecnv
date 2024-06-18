process GERMLINE {
    tag "$sample"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/cmgg/clincnv:1.18.3':
        'cmgg/clincnv:1.18.3' }"
    conda "${moduleDir}/environment.yml"

    publishDir "$params.outdir/clincnv/calling", mode: 'copy'

    input:
    tuple val(meta), val(sample), path(file)
    path(bed)

    output:
    tuple val(meta), val(sample), path("*.tsv"), emit: tsv
    path "versions.yml", emit: versions

    script:
    def publishDir = "$params.outdir/clincnv/calling/"
    def bedDir = "$params.outdir/clincnv"
    def fileDir = "$params.outdir/clincnv/counts/$meta.id"
    def args = task.ext.args ?: ''
    def VERSION = '1.19.0'
    """
    clinCNV.R \\
        --normal ${fileDir}/${file} \\
        --normalSample=${sample} \\
        --bed ${bedDir}/${bed} \\
        --out ${publishDir} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ClinCNV: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """

    stub:
    def VERSION = '1.19.0'
    """
    touch ${sample}.ready_CNVS.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ClinCNV: ${VERSION}
        R: \$(Rscript --version | sed 's/R scripting front-end //g')
    END_VERSIONS
    """
}
