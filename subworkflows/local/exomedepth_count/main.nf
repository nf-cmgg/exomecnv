
// Convert CRAM files
include { COUNT  } from '../../../modules/local/exomedepth/count/main'

workflow EXOMEDEPTH_COUNT {

    take:
    ch_bam // channel: [mandatory] [ val(meta), path(bam), path(bai) ]
    exon_target   // channel: [mandatory] [ val(prefix), path(bed) ]

    main:

    ch_versions = Channel.empty()

    //
    // convert CRAM files to BAM files
    //
    COUNT(ch_bam, exon_target)
    ch_versions = ch_versions.mix(COUNT.out.versions)

    emit:
    count      = COUNT.out.counts           // channel: [ val(meta), [ txt ] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

