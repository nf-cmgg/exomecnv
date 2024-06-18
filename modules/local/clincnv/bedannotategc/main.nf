process BEDANNOTATEGC {

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ngs-bits:2023_02--py311ha0b7adc_2' :
        'biocontainers/ngs-bits:2023_02--py311ha0b7adc_2' }"

    publishDir "$params.outdir/clincnv", mode: 'copy'

    input:
    tuple val(meta), path(exon_target)
    tuple val(meta2), path(fasta)
    tuple val(meta3), path(fai)

    output:
    path("*.bed"), emit: annotatedbed
    path "versions.yml", emit:versions

    script:
    def args = task.ext.args ?: ''
    """
    BedAnnotateGC \\
        -in $exon_target \\
        -out GC_Annotated_$exon_target \\
        -ref $fasta \\

    awk -F'\\t' '{OFS="\\t"; print \$1, \$2, \$3, \$5, \$4}' GC_Annotated_$exon_target > tmp && mv tmp GC_Annotated_$exon_target

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        BedAnnotateGC: \$(BedAnnotateGC --version | sed 's/BedAnnotateGC //g')
    END_VERSIONS
    """

    stub:
    """
    touch GC_Annotated.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        BedCoverage: \$(BedCoverage --version | sed 's/BedCoverage //g')
    END_VERSIONS
    """
}
