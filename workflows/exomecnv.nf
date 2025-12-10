/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_exomecnv_pipeline'

// Modules
include { MULTIQC           } from '../modules/nf-core/multiqc/main'
include { MOSDEPTH          } from '../modules/nf-core/mosdepth/main.nf'
include { BEDGOVCF          } from '../modules/nf-core/bedgovcf/main.nf'
include { BCFTOOLS_SORT     } from '../modules/nf-core/bcftools/sort/main.nf'

// Subworkflows
include { CNV_EXOMEDEPTH            } from '../subworkflows/local/cnv_exomedepth/main'
include { VCF_ANNOTATE_ENSEMBLVEP   } from '../subworkflows/nf-core/vcf_annotate_ensemblvep/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow EXOMECNV {

    take:
    // file inputs
    ch_samplesheet    // channel: samplesheet read in from --input
    ch_roi_input_map  // channel: map of batch to ROI bed file
    outdir
    fasta
    fai
    vep_cache
    bedgovcf_yaml
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    roi_default

    // booleans
    exomedepth
    annotate
    splitx

    // strings
    vep_assembly
    species

    // integers
    vep_cache_version

    main:
    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()
    def ch_fasta = channel.value([ [id: "reference"], file(fasta, checkIfExists:true) ])
    def ch_fai = channel.value([[id: "reference"], file(fai, checkIfExists:true) ])
    def ch_vep_cache = channel.fromPath(vep_cache).collect()

    def ch_input = ch_samplesheet
        .branch { meta, cram, crai, bed, bed_index, vcf, vcf_index ->
            // return a channel with vcf for annotation
            vcf: vcf
                return [ meta, vcf, vcf_index ]
            // return a channel with per-base beds, skipping bam/cram conversion
            bed: bed
                return [ meta, bed, bed_index ]
            // return a channel with bam/cram files when no vcf or bed is provided
            cram: !vcf && !bed
                return [ meta, cram, crai ]
        }

    ch_input.vcf.dump (tag: "VCF INPUT:", pretty:true)
    ch_input.bed.dump (tag: "BED INPUT:", pretty:true)
    ch_input.cram.dump(tag: "BAM/CRAM INPUT:", pretty:true)

    // Generate the raw per-base counts for samples that do not have a VCF or BED file
    MOSDEPTH(
        ch_input.cram.map { meta, cram, crai ->
            return [meta, cram, crai, []]
        },
        ch_fasta
    )
    ch_versions = ch_versions.mix(MOSDEPTH.out.versions.first())
    MOSDEPTH.out.per_base_bed.dump(tag: "MOSDEPTH PER BASE BED:", pretty:true)


    def ch_cnv_vcf = ch_input.vcf
    if (exomedepth) {
        // Generate the ExomeDepth subworkflow input
        ch_perbase = MOSDEPTH.out.per_base_bed
            .join(MOSDEPTH.out.per_base_csi, failOnMismatch:true, failOnDuplicate:true)
            .mix(ch_input.bed)

        CNV_EXOMEDEPTH(
            ch_perbase,
            ch_roi_input_map,
            ch_fai,
            roi_default,
            splitx
        )
        ch_versions = ch_versions.mix(CNV_EXOMEDEPTH.out.versions)

        // Convert bed files to VCF format
        BEDGOVCF(
            CNV_EXOMEDEPTH.out.cnv.map{ meta, bed -> [meta, bed, file(bedgovcf_yaml, checkIfExists:true)]},
            ch_fai
        )
        ch_versions = ch_versions.mix(BEDGOVCF.out.versions.first())

        BCFTOOLS_SORT(
            BEDGOVCF.out.vcf
        )
        ch_versions = ch_versions.mix(BCFTOOLS_SORT.out.versions)

        ch_sorted_vcf_index = BCFTOOLS_SORT.out.vcf.join(BCFTOOLS_SORT.out.tbi, failOnMismatch:true, failOnDuplicate:true)

        // Add the exome depth VCFs to the channel
        ch_cnv_vcf = ch_cnv_vcf.mix(ch_sorted_vcf_index)
    }

    // Annotate exomedepth VCFs and input VCFs
    if(annotate) {
        VCF_ANNOTATE_ENSEMBLVEP(
            ch_cnv_vcf,
            ch_fasta,
            vep_assembly,
            species,
            vep_cache_version,
            ch_vep_cache,
            []
        )
    }

    // Collate and save software versions
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    // MODULE: MultiQC

    def ch_multiqc_config                     = channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    def ch_multiqc_custom_config              = multiqc_config ? channel.fromPath(multiqc_config, checkIfExists: true) : channel.empty()
    def ch_multiqc_logo                       = multiqc_logo ? channel.fromPath(multiqc_logo, checkIfExists: true) : channel.empty()
    def summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary                   = channel.value(paramsSummaryMultiqc(summary_params))
    def ch_multiqc_custom_methods_description = multiqc_methods_description ? file(multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description                = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
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
    multiqc_report = channel.empty()    // channel: /path/to/multiqc_report.html
    versions       = ch_versions        // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
