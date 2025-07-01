/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEDGOVCF              } from '../../../modules/nf-core/bedgovcf/main'
include { BEDTOOLS_MAP          } from '../../../modules/nf-core/bedtools/map/main'
include { CUSTOM_MERGECNV       } from '../../../modules/local/custom/mergecnv/main'
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
    def ch_versions = Channel.empty()
    def ch_count_input = ch_perbase.combine(ch_roi.map{ meta, bed -> ["chromosome": meta.id , "bed": bed]})
        .map { meta, perbase, _index, roi ->
            def chromosome = roi.chromosome
            def bed = roi.bed
            def new_meta = meta + [chromosome:chromosome]
            return [ new_meta, bed, perbase]
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
            [meta, txt, meta.samples.tokenize(","), meta.samples, meta.families]
        }
        .transpose(by:2)
        .map { meta, txt, sample, samples, families ->
            def new_meta = meta + [id:sample]
            [ new_meta, txt, sample, samples, families ]
        }

    EXOMEDEPTH_CALL(
        ch_counts,
        ch_roi
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL.out.versions.first())

    def ch_cnv_out = EXOMEDEPTH_CALL.out.cnvcall
        .map { meta, txt ->
            def new_meta = meta - meta.subMap("chromosome")
            [ new_meta, txt ]
        }

    emit:
    versions = ch_versions
    cnv = ch_cnv_out
}
