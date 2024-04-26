
include { CNV_CALL } from '../../../modules/local/exomedepth/cnv_call/main'

workflow EXOMEDEPTH_CNV {

    take:
    exon_target // channel: [mandatory] [ val(meta), path(bed)]
    cnv_ch // channel: [mandatory] [ val(meta2), val(sample), val(countfile)]

    main:
    ch_versions= Channel.empty()

    CNV_CALL(exon_target, cnv_ch)
    ch_versions = ch_versions.mix(CNV_CALL.out.versions)

    emit:
    cnv = CNV_CALL.out.cnvcall // channel: [ val(meta), [ txt ] ]

    versions = ch_versions
}
