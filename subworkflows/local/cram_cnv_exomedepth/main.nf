/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SAMTOOLS_CONVERT as CRAM_PREPARE              } from '../../../modules/nf-core/samtools/convert/main'
include { EXOMEDEPTH_COUNT as EXOMEDEPTH_COUNT_X        } from '../../../modules/local/exomedepth/count/main'
include { EXOMEDEPTH_COUNT as EXOMEDEPTH_COUNT_AUTO     } from '../../../modules/local/exomedepth/count/main'
include { CUSTOM_MERGECOUNTS as CUSTOM_MERGECOUNTS_AUTO } from '../../../modules/local/custom/mergecounts/main'
include { CUSTOM_MERGECOUNTS as CUSTOM_MERGECOUNTS_X    } from '../../../modules/local/custom/mergecounts/main'
include { EXOMEDEPTH_CALL as EXOMEDEPTH_CALL_AUTO       } from '../../../modules/local/exomedepth/call/main'
include { EXOMEDEPTH_CALL as EXOMEDEPTH_CALL_X          } from '../../../modules/local/exomedepth/call/main'
include { CUSTOM_MERGECNV                               } from '../../../modules/local/custom/mergecnv/main'
include { BEDGOVCF                                      } from '../../../modules/nf-core/bedgovcf/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CRAM_CNV_EXOMEDEPTH {

    take:
    ch_samplesheet

    main:
    def ch_versions = Channel.empty()

    // Importing and convert the input files passed through the parameters to channels
    // Branch into CRAM and BAM files

    def ch_input_prepare = ch_samplesheet.branch { _meta, cram, _crai ->
            cram: cram.extension == "cram"
            bam: cram.extension == "bam"
        }

    def ch_fasta    = Channel.fromPath(params.fasta).map{ fasta -> [[id:"reference"], fasta]}.collect()
    def ch_fai      = params.fai ? Channel.fromPath(params.fai).map{ fai -> [[id:"reference"], fai]}.collect() : null
    def ch_roi_auto = Channel.fromPath(params.roi_auto).map{ bed -> [[id:"autosomal"], bed]}.collect()
    def ch_roi_x    = Channel.fromPath(params.roi_chrx).map{ bed -> [[id:"chrX"], bed]}.collect()

    // SUBWORKFLOW: Convert CRAM to BAM if no BAM file was provided

    CRAM_PREPARE (
        ch_input_prepare.cram,
        ch_fasta,
        ch_fai
    )
    ch_versions = ch_versions.mix(CRAM_PREPARE.out.versions.first())

    def ch_cram_prepare = CRAM_PREPARE.out.bam
        .join(CRAM_PREPARE.out.bai, failOnMismatch:true, failOnDuplicate:true)

    def ch_input_bam = ch_input_prepare.bam
        .mix(ch_cram_prepare)

    //MODULE: Count autosomal reads per sample (count file for each sample)

    EXOMEDEPTH_COUNT_AUTO (
        ch_input_bam,
        ch_roi_auto
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_COUNT_AUTO.out.versions.first())

    //MODULE: Group autosomal counts per pool (count file for each pool)

    def grouped_counts_auto = EXOMEDEPTH_COUNT_AUTO.out.counts
        .map { meta, txt ->
            def new_meta = [id:meta.pool]
            [new_meta, meta.sample, meta.family, txt]
        }
        .groupTuple()
        .map { meta, samples, families, txt ->
            def new_meta = [id:meta.id, chr:"autosomal", sam:samples, fam: families]
            [new_meta, txt]
        }

    CUSTOM_MERGECOUNTS_AUTO (
        grouped_counts_auto
    )
    ch_versions = ch_versions.mix(CUSTOM_MERGECOUNTS_AUTO.out.versions.first())

    //MODULE: Autosomal CNV call per sample (file for each sample)

    def cnv_auto_ch = CUSTOM_MERGECOUNTS_AUTO.out.merge
        .map { meta, txt ->
            [meta, meta.sam, txt]
        }
        .transpose(by:1)

    EXOMEDEPTH_CALL_AUTO(
        ch_roi_auto,
        cnv_auto_ch
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL_AUTO.out.versions.first())

    //MODULE: Count chrX reads per sample (count file for each sample)

    EXOMEDEPTH_COUNT_X(
        ch_input_bam,
        ch_roi_x
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_COUNT_X.out.versions.first())

    //MODULE: Group chrX counts per pool (count file for each pool)

    def grouped_counts_X = EXOMEDEPTH_COUNT_X.out.counts
        .map { meta, txt ->
            def new_meta = [id:meta.pool]
            [new_meta, meta.sample, meta.family, txt]
        }
        .groupTuple() // TODO fix this bottleneck
        .map { meta, samples, families, txt ->
            def new_meta = [id:meta.id, chr:"chrX", sam:samples, fam: families]
            [new_meta, txt]
        }

    CUSTOM_MERGECOUNTS_X (
        grouped_counts_X
    )
    ch_versions = ch_versions.mix(CUSTOM_MERGECOUNTS_X.out.versions.first())

    //MODULE: ChrX CNV call per sample (file for each sample)

    def cnv_chrx_ch = CUSTOM_MERGECOUNTS_X.out.merge
        .map { meta, txt ->
            [meta, meta.sam, txt]
        }
        .transpose(by:1)

    EXOMEDEPTH_CALL_X(
        ch_roi_x,
        cnv_chrx_ch
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL_X.out.versions.first())

    //MODULE: Group autosomal and chrX CNV per sample (one file for each sample)

    def cnv_merge_ch = EXOMEDEPTH_CALL_AUTO.out.cnvcall
        .combine(EXOMEDEPTH_CALL_X.out.cnvcall, by:1)
        .map{ sample, _meta, auto, _meta2, x ->
            [sample, auto, x]
        }

    CUSTOM_MERGECNV(cnv_merge_ch)
    ch_versions = ch_versions.mix(CUSTOM_MERGECNV.out.versions.first())

    //MODULE: Convert file to VCF according to a YAML config

    def bedgovcf_input = CUSTOM_MERGECNV.out.merge
        .map{ meta, bed ->
            def new_meta = [id:meta]
            [new_meta, bed, params.yamlconfig]
        }

    BEDGOVCF(
        bedgovcf_input,
        ch_fai
    )
    ch_versions = ch_versions.mix(BEDGOVCF.out.versions.first())

    emit:
    versions = ch_versions
    vcf = BEDGOVCF.out.vcf
}

