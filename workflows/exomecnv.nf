/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_exomecnv_pipeline'

// local
include { CRAM_PREPARE                               } from '../subworkflows/local/cram_prepare/main'
include { EXOMEDEPTH_COUNT as COUNT_X                } from '../subworkflows/local/exomedepth_count/main'
include { EXOMEDEPTH_COUNT as COUNT_AUTO             } from '../subworkflows/local/exomedepth_count/main'
include { EXOMEDEPTH_COUNT_MERGE as COUNT_MERGE_AUTO } from '../modules/local/exomedepth/merge_count/main'
include { EXOMEDEPTH_COUNT_MERGE as COUNT_MERGE_X    } from '../modules/local/exomedepth/merge_count/main'


// include { BAM_VARIANT_CALLING_EXOMEDEPTH } from '../subworkflows/local/bam_variant_calling_exomedepth/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXOMECNV {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // Importing and convert the input files passed through the parameters to channels
    //

    // branch into CRAM and BAM files
    ch_samplesheet.branch { meta, cram, crai ->
                CRAM: cram.extension == "cram"
                BAM: cram.extension == "bam"
            }
            .set{ ch_input_prepare }


   //ch_input_prepare.BAM.view { "BAM: $it" }
   //ch_input_prepare.CRAM.view { "CRAM: $it" }


    ch_fasta        = Channel.fromPath(params.fasta).map{ [[id:"reference"], it]}.collect()
    ch_fai          = params.fai ? Channel.fromPath(params.fai).map{ [[id:"reference"], it]}.collect() : null
    ch_roi_auto     = Channel.fromPath(params.roi_auto).map{ [[id:"autosomal"], it]}.collect()
    ch_roi_x        = Channel.fromPath(params.roi_chrx).map{ [[id:"chrX"], it]}.collect()

    // ch_fasta.view()
    // ch_fai.view()
    // ch_roi_auto.view()
    // ch_roi_auto.view()

    // SUBWORKFLOW: Convert CRAM to BAM if no BAM file was provided
    CRAM_PREPARE (
        ch_input_prepare.CRAM, ch_fasta, ch_fai
    )
    // ch_input_prepare.BAM.view{ "BAM: $it" }
    // CRAM_PREPARE.out.bai.view{ "samtools: $it" }
    CRAM_PREPARE.out.bam
                .join(CRAM_PREPARE.out.bai)
                .set{ ch_cram_prepare }

    ch_input_prepare.BAM
                    .mix(ch_cram_prepare)
                    .set{ ch_input_bam }

    // ch_input_bam.view()
    COUNT_AUTO (
        ch_input_bam, ch_roi_auto
    )

    grouped_counts_auto = COUNT_AUTO.out.count
        .map { meta, txt ->
            def new_meta = [id:meta.pool,chr:"autosomal"]
            [new_meta, txt]
    }
    .groupTuple()

    COUNT_MERGE_AUTO (
    grouped_counts_auto
    )

    COUNT_X (
        ch_input_bam, ch_roi_x
    )

    grouped_counts_X = COUNT_X.out.count
        .map { meta, txt ->
            def new_meta = [id:meta.pool,chr:"chrX"]
            [new_meta, txt]
    }
    .groupTuple()

    COUNT_MERGE_X (
        grouped_counts_X
    )
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
