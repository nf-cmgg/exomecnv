/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { BEDCOVERAGE    } from '../../../modules/local/clincnv/bedcoverage/main'
include { COVERAGE_MERGE } from '../../../modules/local/clincnv/merge_coverage/main'
include { PATHFILE       } from '../../../modules/local/clincnv/pathfile/main'
include { BEDANNOTATEGC  } from '../../../modules/local/clincnv/bedannotategc/main'
include { GERMLINE       } from '../../../modules/local/clincnv/germline/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CLINCNV {

    take:
    ch_samplesheet
    ch_fasta
    ch_fai

    main:
    ch_versions = Channel.empty()

    ch_roi_merged = Channel.fromPath(params.roi_merged).map{ [[id:"chr21X"], it]}.collect()

    BEDCOVERAGE(ch_samplesheet,ch_roi_merged)
    ch_versions = ch_versions.mix(BEDCOVERAGE.out.versions)

    grouped_counts = BEDCOVERAGE.out.counts
        .map { meta, txt ->
            def new_meta = [id:meta.pool]
            [new_meta, meta.sample, txt]
            }
        .groupTuple()

    PATHFILE(grouped_counts)

    COVERAGE_MERGE(PATHFILE.out.counts)
    ch_versions = ch_versions.mix(COVERAGE_MERGE.out.versions)

    BEDANNOTATEGC(ch_roi_merged, ch_fasta, ch_fai)
    ch_versions = ch_versions.mix(BEDANNOTATEGC.out.versions)

    ch_clincnv = COVERAGE_MERGE.out.merge.transpose(by:1)

    // GERMLINE(ch_clincnv,BEDANNOTATEGC.out.annotatedbed)
    // ch_versions = ch_versions.mix(GERMLINE.out.versions)

    emit:
    versions = ch_versions

}
