/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEDTOOLS_MAP          } from '../../../modules/nf-core/bedtools/map/main'
include { CUSTOM_MERGECOUNTS    } from '../../../modules/local/custom/mergecounts/main'
include { CUSTOM_REFORMATCOUNTS } from '../../../modules/local/custom/reformatcounts/main'
include { GREP_SPLITBED         } from '../../../modules/local/grep/splitbed/main'
include { CUSTOM_MERGECALLS     } from '../../../modules/local/custom/mergecalls/main'
include { EXOMEDEPTH_CALL       } from '../../../modules/local/exomedepth/call/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CNV_EXOMEDEPTH {

    take:
    ch_perbase  // channel: meta, bed, index
    ch_roi      // value:   map<string, path>
    ch_fai      // value:   meta, path
    roi_default // value:   path
    splitx      // boolean

    main:
    def ch_versions = channel.empty()
    def ch_count_input = ch_perbase.combine(ch_roi)
        .map { meta, perbase, _index, roi_map ->
            return [ meta, roi_map.get(meta.batch, roi_default), perbase ]
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
            [meta, txt, meta.samples.tokenize(","), meta.samples, meta.families]
        }
        .transpose(by:2)
        .map { meta, txt, sample, samples, families ->
            def new_meta = meta + [id:sample]
            [ new_meta, txt, sample, samples, families ]
        }

    def ch_exomedepth_input = channel.empty()
    if(splitx) {
        // Rare name will be used for the default ROI to reduce the chance of name collisions
        def rare_name = "f632d51cf1eede42b6b8c0eb965f438a"
        def ch_all_rois = channel.fromPath(roi_default).map { file -> [[id:rare_name], file] }
            .mix(ch_roi.map { map -> map.collect { entry -> [[id: entry.key], entry.value] }}.flatMap() )

        GREP_SPLITBED (
            ch_all_rois
        )
        ch_versions = ch_versions.mix(GREP_SPLITBED.out.versions.first())

        def ch_autosomal_input = ch_counts.combine(GREP_SPLITBED.out.bed_autosomal.collect { item -> [item] }.map { items -> [items] })
            .map { meta, txt, sample, samples, families, autosomal_list ->
                def new_meta = meta + [region:'autosomal']
                def roi = autosomal_list.find { entry -> entry[0].id == meta.batch } ?: autosomal_list.find { entry -> entry[0].id == rare_name }
                [ new_meta, txt, sample, samples, families, roi[1] ]
            }
            .filter { _meta, _txt, _sample, _samples, _families, roi ->
                // Remove any entries with an empty ROI
                roi.size() > 0
            }

        def ch_chrx_input = ch_counts.combine(GREP_SPLITBED.out.bed_chrx.collect { item -> [item] }.map { items -> [items] })
            .map { meta, txt, sample, samples, families, chrx_list ->
                def new_meta = meta + [region:'chrx']
                def roi = chrx_list.find { entry -> entry[0].id == meta.batch } ?: chrx_list.find { entry -> entry[0].id == rare_name }
                [ new_meta, txt, sample, samples, families, roi[1] ]
            }
            .filter { _meta, _txt, _sample, _samples, _families, roi ->
                // Remove any entries with an empty ROI
                roi.size() > 0
            }

        ch_exomedepth_input = ch_autosomal_input.mix(ch_chrx_input)
    } else {
        ch_exomedepth_input = ch_counts.combine(ch_roi)
            .map { meta, txt, sample, samples, families, roi_map ->
                [ meta, txt, sample, samples, families, roi_map.get(meta.batch, roi_default) ]
            }
    }

    EXOMEDEPTH_CALL(
        ch_exomedepth_input
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL.out.versions.first())

    def ch_cnv_out = channel.empty()
    if (splitx) {
        def ch_merge_input = EXOMEDEPTH_CALL.out.cnvcall
            .map { meta, txt ->
                def new_meta = meta - meta.subMap("region")
                [ new_meta, txt ]
            }
            .groupTuple(size:2, remainder:true)

        CUSTOM_MERGECALLS(
            ch_merge_input
        )
        ch_versions = ch_versions.mix(CUSTOM_MERGECALLS.out.versions.first())
        ch_cnv_out = CUSTOM_MERGECALLS.out.merge
    } else {
        ch_cnv_out = EXOMEDEPTH_CALL.out.cnvcall
    }

    emit:
    versions = ch_versions
    cnv = ch_cnv_out
}
