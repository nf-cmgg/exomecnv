/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEDTOOLS_MAP          } from '../../../modules/nf-core/bedtools/map/main'
include { CUSTOM_MERGECOUNTS    } from '../../../modules/local/custom/mergecounts/main'
include { CUSTOM_REFORMATCOUNTS } from '../../../modules/local/custom/reformatcounts/main'
include { EXOMEDEPTH_CALL       } from '../../../modules/local/exomedepth/call/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CNV_EXOMEDEPTH {

    take:
    ch_perbase  // meta, bed, index
    ch_roi      // meta, bed
    ch_fai      // meta, path

    main:
    def ch_versions = channel.empty()
    def ch_count_input = ch_perbase.join(ch_roi, failOnMismatch: true, failOnDuplicate: true)
        .map { meta, perbase, _index, roi ->
            def new_meta = meta + [roi:roi]
            return [ new_meta, roi, perbase ]
        }

    // Calculate the mean coverage from the per-base coverage files for the exons in the ROI
    BEDTOOLS_MAP (
        ch_count_input,
        ch_fai
    )
    ch_versions = ch_versions.mix(BEDTOOLS_MAP.out.versions.first())


    //MODULE: Group counts per batch (count file for each batch)
    CUSTOM_REFORMATCOUNTS (
        BEDTOOLS_MAP.out.mapped
    )
    ch_versions = ch_versions.mix(CUSTOM_REFORMATCOUNTS.out.versions.first())
    def ch_grouped_counts_header = CUSTOM_REFORMATCOUNTS.out.header
        .map { meta, tsv ->
            def new_meta = meta + [id:meta.batch] - meta.subMap("family")
            [groupKey(new_meta, new_meta.samples.tokenize(",").size), tsv]
        }
        .groupTuple()

    CUSTOM_MERGECOUNTS(
        ch_grouped_counts_header
    )

    ch_versions = ch_versions.mix(CUSTOM_MERGECOUNTS.out.versions.first())

    def ch_counts = CUSTOM_MERGECOUNTS.out.merge
        .map { meta, txt ->
            def new_meta = meta - meta.subMap("roi")
            [new_meta, txt, meta.samples.tokenize(","), meta.samples, meta.families, meta.roi]
        }
        .transpose(by:2)
        .map { meta, txt, sample, samples, families, roi ->
            def new_meta = meta + [id:sample]
            [ new_meta, txt, sample, samples, families, roi ]
        }

    EXOMEDEPTH_CALL(
        ch_counts,
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL.out.versions.first())

    def ch_cnv_out = EXOMEDEPTH_CALL.out.cnvcall

    emit:
    versions = ch_versions
    cnv = ch_cnv_out
}
