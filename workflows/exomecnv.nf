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
include { EXOMEDEPTH                                } from '../subworkflows/local/exomedepth/main'
include { VCF_ANNOTATION as ANNOTATION_FROM_CRAM    } from '../subworkflows/local/vcf_annotation/main'
include { VCF_ANNOTATION as ANNOTATION_FROM_VCF     } from '../subworkflows/local/vcf_annotation/main'
include { TABIX_TABIX as TABIX                      } from '../modules/nf-core/tabix/tabix/main'

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

    ch_fasta = channel.fromPath(params.fasta)
        .map{ path ->
        def new_meta = [id:"reference"]
        [new_meta, path]
        }
        .collect()

    ch_vep_cache = Channel.fromPath(params.vep_cache).collect()

    ch_samplesheet.branch { meta, cram, crai, vcf, tbi ->
                vcf: vcf
                    return [ meta, cram, crai, vcf, tbi]
                no_vcf: !vcf
                    return [ meta, cram, crai]}
                .set{ ch_input }

    // ExomeDepth
    if (ch_input.no_vcf) {
    if (params.exomedepth) {
    EXOMEDEPTH (ch_input.no_vcf)
    ch_versions = ch_versions.mix(EXOMEDEPTH.out.versions)

    // Index files for VCF

    TABIX ( EXOMEDEPTH.out.vcf )
    ch_versions = ch_versions.mix(TABIX.out.versions)
    ch_exomedepth_vcf = EXOMEDEPTH.out.vcf
        .join(TABIX.out.tbi)

    // EnsemblVEP after ExomeDepth

    if (params.annotate) {

    ANNOTATION_FROM_CRAM ( ch_exomedepth_vcf, ch_fasta, ch_vep_cache )
    ch_versions = ch_versions.mix(ANNOTATION_FROM_CRAM.out.versions)

    }
    }
    }

    // EnsemblVEP on VCF input file

    if (ch_input.vcf) {
    ch_vcf = ch_input.vcf
        .map { meta,bam,bai,vcf,tbi ->
                [[id:meta.id], vcf, tbi]}

    ANNOTATION_FROM_VCF (
        ch_vcf, ch_fasta, ch_vep_cache
    )
    ch_versions = ch_versions.mix(ANNOTATION_FROM_VCF.out.versions)
    }

    // Collate and save software versions

    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    // MODULE: MultiQC

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
