/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SAMTOOLS_CONVERT as CRAM_PREPARE  } from '../../../modules/nf-core/samtools/convert/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN INPUT PREPARE WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow INPUT_PREPARE {

    take:
    ch_samplesheet

    main:
    ch_versions = Channel.empty()

    ch_samplesheet.branch { meta, cram, crai ->
                    CRAM: cram.extension == "cram"
                    BAM: cram.extension == "bam"
                }
                .set{ ch_input_prepare }

    ch_fasta        = Channel.fromPath(params.fasta).map{ [[id:"reference"], it]}.collect()
    ch_fai          = params.fai ? Channel.fromPath(params.fai).map{ [[id:"reference"], it]}.collect() : null

    CRAM_PREPARE (
        ch_input_prepare.CRAM, ch_fasta, ch_fai
    )
    ch_versions = ch_versions.mix(CRAM_PREPARE.out.versions)

    CRAM_PREPARE.out.bam
                .join(CRAM_PREPARE.out.bai)
                .set{ ch_cram_prepare }

    ch_input_prepare.BAM
                    .mix(ch_cram_prepare)
                    .set{ ch_input_bam }

    emit:
    versions = ch_versions
    bam = ch_input_bam
}
