/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SAMTOOLS_CONVERT as CRAM_PREPARE  } from '../../../modules/nf-core/samtools/convert/main'
include { COUNT as COUNT_X                  } from '../../../modules/local/exomedepth/count/main'
include { COUNT as COUNT_AUTO               } from '../../../modules/local/exomedepth/count/main'
include { COUNT_MERGE as COUNT_MERGE_AUTO   } from '../../../modules/local/exomedepth/merge_count/main'
include { COUNT_MERGE as COUNT_MERGE_X      } from '../../../modules/local/exomedepth/merge_count/main'
include { CNV_CALL as CNV_CALL_AUTO         } from '../../../modules/local/exomedepth/cnv_call/main'
include { CNV_CALL as CNV_CALL_X            } from '../../../modules/local/exomedepth/cnv_call/main'
include { CNV_MERGE                         } from '../../../modules/local/exomedepth/merge_cnv/main'
include { BEDGOVCF                          } from '../../../modules/nf-core/bedgovcf/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXOMEDEPTH {

    take:
    ch_samplesheet

    main:
    ch_versions = Channel.empty()

    // Importing and convert the input files passed through the parameters to channels
    // Branch into CRAM and BAM files

    ch_samplesheet.map { meta, cram, crai, vcf, tbi ->
                        [meta, cram, crai]}
                .branch { meta, cram, crai ->
                    CRAM: cram.extension == "cram"
                    BAM: cram.extension == "bam"
                }
                .set{ ch_input_prepare }

    ch_fasta        = Channel.fromPath(params.fasta).map{ [[id:"reference"], it]}.collect()
    ch_fai          = params.fai ? Channel.fromPath(params.fai).map{ [[id:"reference"], it]}.collect() : null
    ch_roi_auto     = Channel.fromPath(params.roi_auto).map{ [[id:"autosomal"], it]}.collect()
    ch_roi_x        = Channel.fromPath(params.roi_chrx).map{ [[id:"chrX"], it]}.collect()

    // SUBWORKFLOW: Convert CRAM to BAM if no BAM file was provided

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

    //MODULE: Count autosomal reads per sample (count file for each sample)

    COUNT_AUTO (
        ch_input_bam, ch_roi_auto
    )
    ch_versions = ch_versions.mix(COUNT_AUTO.out.versions)

    //MODULE: Group autosomal counts per pool (count file for each pool)

    grouped_counts_auto = COUNT_AUTO.out.counts
        .map { meta, txt ->
            def new_meta = [id:meta.pool]
            [new_meta, meta.sample, meta.family, txt]
            }
        .groupTuple()
        .map { meta, samples, families, txt ->
            def new_meta = [id:meta.id, chr:"autosomal", sam:samples, fam: families]
            [new_meta, txt]
        }

    COUNT_MERGE_AUTO (
        grouped_counts_auto
    )
    ch_versions = ch_versions.mix(COUNT_MERGE_AUTO.out.versions)

    //MODULE: Autosomal CNV call per sample (file for each sample)

    cnv_auto_ch = COUNT_MERGE_AUTO.out.merge
        .map { meta, txt ->
            [meta, meta.sam, txt]
            }
        .transpose(by:1)

    CNV_CALL_AUTO(
        ch_roi_auto, cnv_auto_ch
    )
    ch_versions = ch_versions.mix(CNV_CALL_AUTO.out.versions)

    //MODULE: Count chrX reads per sample (count file for each sample)

    COUNT_X (
        ch_input_bam, ch_roi_x
    )

    //MODULE: Group chrX counts per pool (count file for each pool)

    grouped_counts_X = COUNT_X.out.counts
        .map { meta, txt ->
            def new_meta = [id:meta.pool]
            [new_meta, meta.sample, meta.family, txt]
            }
        .groupTuple()
        .map { meta, samples, families, txt ->
            def new_meta = [id:meta.id, chr:"chrX", sam:samples, fam: families]
            [new_meta, txt]
        }

    COUNT_MERGE_X (
        grouped_counts_X
    )

    //MODULE: ChrX CNV call per sample (file for each sample)

    cnv_chrx_ch = COUNT_MERGE_X.out.merge
        .map { meta, txt ->
            [meta, meta.sam, txt]
            }
        .transpose(by:1)

    CNV_CALL_X(
        ch_roi_auto, cnv_chrx_ch
    )

    //MODULE: Group autosomal and chrX CNV per sample (one file for each sample)

    cnv_merge_ch = CNV_CALL_AUTO.out.cnvcall
            .combine(CNV_CALL_X.out.cnvcall, by:1)
            .map{ sample, meta, auto, meta2, x ->
                [sample, auto, x]
                }

    CNV_MERGE(cnv_merge_ch)
    ch_versions = ch_versions.mix(CNV_MERGE.out.versions)

    //MODULE: Convert file to VCF according to a YAML config

    bedgovcf_input = CNV_MERGE.out.merge
                .map{ meta, bed ->
                    def new_meta = [id:meta]
                    [new_meta, bed, params.yamlconfig]
                }

    BEDGOVCF(bedgovcf_input, ch_fai)
    ch_versions = ch_versions.mix(BEDGOVCF.out.versions)

    emit:
    versions = ch_versions
    vcf = BEDGOVCF.out.vcf
}

