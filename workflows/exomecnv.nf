/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_exomecnv_pipeline'

// local
include { CRAM_CNV_EXOMEDEPTH   } from '../subworkflows/local/cram_cnv_exomedepth/main'
include { VCF_ANNOTATE_VEP      } from '../subworkflows/local/vcf_annotate_vep/main'
include { TABIX_TABIX as TABIX  } from '../modules/nf-core/tabix/tabix/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXOMECNV {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:
    def ch_versions = Channel.empty()
    def ch_multiqc_files = Channel.empty()

    def ch_fasta = channel.fromPath(params.fasta)
        .map{ path ->
            def new_meta = [id:"reference"]
            [new_meta, path]
        }
        .collect()

    def ch_vep_cache = Channel.fromPath(params.vep_cache).collect()

    ch_samplesheet.branch { meta, cram, crai, vcf, tbi ->
            vcf: vcf
                return [ meta, vcf, tbi]
            no_vcf: !vcf
                return [ meta, cram, crai]
        }
        .set{ ch_input }

    // ExomeDepth
    def ch_exomedepth_vcf = Channel.empty()
    if (params.exomedepth) {
        CRAM_CNV_EXOMEDEPTH(ch_input.no_vcf)
        ch_versions = ch_versions.mix(CRAM_CNV_EXOMEDEPTH.out.versions)

        // Index files for VCF

        TABIX(CRAM_CNV_EXOMEDEPTH.out.vcf)
        ch_versions = ch_versions.mix(TABIX.out.versions)
        ch_exomedepth_vcf = CRAM_CNV_EXOMEDEPTH.out.vcf
            .join(TABIX.out.tbi, failOnMismatch:true, failOnDuplicate:true)
    }

    // Annotate exomedepth VCFs and input VCFs
    def ch_annotate_input = ch_exomedepth_vcf.mix(ch_input.vcf)
    if(params.annotate) {
        VCF_ANNOTATE_VEP(
            ch_annotate_input,
            ch_fasta,
            ch_vep_cache
        )
    }

    // Collate and save software versions

    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    // MODULE: MultiQC

    def ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    def ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    def ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    def summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    def ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
        ch_multiqc_files                      = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
        ch_multiqc_files                      = ch_multiqc_files.mix(ch_collated_versions)
        ch_multiqc_files                      = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
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
