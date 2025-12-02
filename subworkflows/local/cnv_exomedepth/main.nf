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
    def default_name = "f632d51cf1eede42b6b8c0eb965f438a"

    def ch_count_input = channel.empty()
    if(splitx) {
        def split_input = ch_roi
            .flatMap { roi_map ->
                return roi_map.collect { entry -> [[id: entry.key], entry.value] }
            }
            .mix(channel.fromPath(roi_default).map { file -> [[id: default_name], file] } )

        GREP_SPLITBED(
            split_input
        )
        ch_versions = ch_versions.mix(GREP_SPLITBED.out.versions.first())

        def ch_roi_x = GREP_SPLITBED.out.bed_chrx.collect { meta, file -> [["${meta.id}", file]]}.view()
            .map { items ->
                def map = [:]
                items.each { entry ->
                    map[entry[0]] = entry[1]
                }
                return map
            }.view()

        def ch_roi_auto = GREP_SPLITBED.out.bed_autosomal.collect { meta, file -> [["${meta.id}", file]]}
            .map { items ->
                def map = [:]
                items.each { entry ->
                    map[entry[0]] = entry[1]
                }
                return map
            }

        def ch_x_count_input = ch_perbase.combine(ch_roi_x)
            .map { meta, perbase, _index, roi_map ->
                def roi = roi_map.get(meta.batch) ?: roi_map.get(default_name)
                def new_meta = meta + [region:'chrx', roi:roi]
                return [ new_meta, roi, perbase ]
            }

        def ch_auto_count_input = ch_perbase.combine(ch_roi_auto)
            .map { meta, perbase, _index, roi_map ->
                def roi = roi_map.get(meta.batch) ?: roi_map.get(default_name)
                def new_meta = meta + [region:'autosomal', roi:roi]
                return [ new_meta, roi, perbase ]
            }

        ch_count_input = ch_x_count_input
            .mix(ch_auto_count_input)
            .filter { _meta, roi, _perbase ->
                // Ensure that the ROI is not empty or we are in stub run mode
                return roi.size() > 0 || workflow.stubRun
            }

    } else {
        ch_count_input = ch_perbase.combine(ch_roi)
            .map { meta, perbase, _index, roi_map ->
                def roi = roi_map.get(meta.batch, roi_default)
                def new_meta = meta + [roi:roi]
                return [ new_meta, roi, perbase ]
            }
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

    def ch_exomedepth_input = ch_counts
        .map { meta, txt, sample, samples, families ->
            def new_meta = meta - meta.subMap("roi")
            [ new_meta, txt, sample, samples, families, meta.roi ]
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
