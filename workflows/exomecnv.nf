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

// Modules
include { TABIX_TABIX       } from '../modules/nf-core/tabix/tabix/main'
include { SAMTOOLS_CONVERT  } from '../modules/nf-core/samtools/convert/main'
include { CUSTOM_MERGECNV   } from '../modules/local/custom/mergecnv/main.nf'
include { BEDGOVCF          } from '../modules/nf-core/bedgovcf/main.nf'

// Subworkflows
include { CRAM_CNV_EXOMEDEPTH as CRAM_CNV_EXOMEDEPTH_X      } from '../subworkflows/local/cram_cnv_exomedepth/main'
include { CRAM_CNV_EXOMEDEPTH as CRAM_CNV_EXOMEDEPTH_AUTO   } from '../subworkflows/local/cram_cnv_exomedepth/main'
include { VCF_ANNOTATE_VEP                                  } from '../subworkflows/local/vcf_annotate_vep/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXOMECNV {

    take:
    // file inputs
    ch_samplesheet // channel: samplesheet read in from --input
    outdir
    fasta
    fai
    roi_auto
    roi_chrx
    vep_cache
    bedgovcf_yaml
    multiqc_config
    multiqc_logo
    multiqc_methods_description

    // booleans
    exomedepth
    annotate

    // strings
    vep_assembly
    species

    // integers
    vep_cache_version

    main:
    def ch_versions = Channel.empty()
    def ch_multiqc_files = Channel.empty()

    def ch_fasta = Channel.fromPath(fasta)
        .map{ path ->
            def new_meta = [id:"reference"]
            [new_meta, path]
        }
        .collect()

    def ch_fai = Channel.fromPath(fai)
        .map{ path ->
            def new_meta = [id:"reference"]
            [new_meta, path]
        }
        .collect()

    def ch_roi_auto = Channel.fromPath(roi_auto)
        .map{ bed -> [[id:"autosomal"], bed]}
        .collect()

    def ch_roi_x    = Channel.fromPath(roi_chrx)
        .map{ bed -> [[id:"chrX"], bed]}
        .collect()

    def ch_vep_cache = Channel.fromPath(vep_cache).collect()

    def ch_input = ch_samplesheet.branch { meta, cram, crai, vcf, tbi ->
            vcf: vcf
                return [ meta, vcf, tbi ]
            no_vcf: !vcf
                return [ meta, cram, crai ]
        }

    // ExomeDepth
    def ch_exomedepth_vcf = Channel.empty()
    if (exomedepth) {
        def ch_cram_bam = ch_input.no_vcf.branch { _meta, file, _index ->
            cram: file.extension == "cram"
            bam:  file.extension == "bam"
        }

        SAMTOOLS_CONVERT(
            ch_cram_bam.cram,
            ch_fasta,
            ch_fai
        )
        ch_versions = ch_versions.mix(SAMTOOLS_CONVERT.out.versions.first())

        def ch_exomedepth_input = ch_cram_bam.bam
            .mix(
                SAMTOOLS_CONVERT.out.bam.join(SAMTOOLS_CONVERT.out.bai, failOnMismatch:true, failOnDuplicate:true)
            )

        CRAM_CNV_EXOMEDEPTH_X(
            ch_exomedepth_input,
            ch_roi_x,
            "chrX"
        )
        ch_versions = ch_versions.mix(CRAM_CNV_EXOMEDEPTH_X.out.versions)

        CRAM_CNV_EXOMEDEPTH_AUTO(
            ch_exomedepth_input,
            ch_roi_auto,
            "autosomal"
        )
        ch_versions = ch_versions.mix(CRAM_CNV_EXOMEDEPTH_X.out.versions)

        def ch_merge_input = CRAM_CNV_EXOMEDEPTH_X.out.cnv
            .join(CRAM_CNV_EXOMEDEPTH_AUTO.out.cnv)

        CUSTOM_MERGECNV(
            ch_merge_input
        )
        ch_versions = ch_versions.mix(CUSTOM_MERGECNV.out.versions.first())

        def bedgovcf_input = CUSTOM_MERGECNV.out.merge
            .map{ meta, bed ->
                [meta, bed, file(bedgovcf_yaml, checkIfExists:true)]
            }

        BEDGOVCF(
            bedgovcf_input,
            ch_fai
        )
        ch_versions = ch_versions.mix(BEDGOVCF.out.versions.first())

        // Index files for VCF

        TABIX_TABIX(
            BEDGOVCF.out.vcf
        )
        ch_versions = ch_versions.mix(TABIX_TABIX.out.versions)

        ch_exomedepth_vcf = BEDGOVCF.out.vcf
            .join(TABIX_TABIX.out.tbi, failOnMismatch:true, failOnDuplicate:true)
    }

    // Annotate exomedepth VCFs and input VCFs
    def ch_annotate_input = ch_exomedepth_vcf.mix(ch_input.vcf)
    if(annotate) {
        VCF_ANNOTATE_VEP(
            ch_annotate_input,
            ch_fasta,
            ch_vep_cache,
            vep_assembly,
            species,
            vep_cache_version
        )
    }

    // Collate and save software versions

    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    // MODULE: MultiQC

    def ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    def ch_multiqc_custom_config              = multiqc_config ? Channel.fromPath(multiqc_config, checkIfExists: true) : Channel.empty()
    def ch_multiqc_logo                       = multiqc_logo ? Channel.fromPath(multiqc_logo, checkIfExists: true) : Channel.empty()
    def summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    def ch_multiqc_custom_methods_description = multiqc_methods_description ? file(multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
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
    multiqc_report = Channel.empty() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
