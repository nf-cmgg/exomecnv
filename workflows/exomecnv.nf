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
    def ch_multiqc_files = channel.empty()
    def ch_fasta = channel.value([ [id: "reference"], fasta ])
    def ch_fai = channel.value([[id: "reference"], fai ])
    def ch_vep_cache = channel.value([ [id: "vep_cache"], vep_cache ])

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
        ch_fasta,
        []
    )
    MOSDEPTH.out.per_base_bed.dump(tag: "MOSDEPTH PER BASE BED:", pretty:true)


    def ch_cnv_vcf = ch_input.vcf
    def count_files = channel.empty()
    def cnv_vcfs_created = channel.empty()
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
        count_files = CNV_EXOMEDEPTH.out.counts

        // Convert bed files to VCF format
        BEDGOVCF(
            CNV_EXOMEDEPTH.out.cnv.map{ meta, bed -> [meta, bed, bedgovcf_yaml]},
            ch_fai
        )

        BCFTOOLS_SORT(
            BEDGOVCF.out.vcf
        )

        cnv_vcfs_created = BCFTOOLS_SORT.out.vcf.join(BCFTOOLS_SORT.out.tbi, failOnMismatch:true, failOnDuplicate:true)

        // Add the exome depth VCFs to the channel
        ch_cnv_vcf = ch_cnv_vcf.mix(cnv_vcfs_created)
    }

    // Annotate exomedepth VCFs and input VCFs
    def vep_vcfs = channel.empty()
    def annotation_summary = channel.empty()
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
        vep_vcfs = VCF_ANNOTATE_ENSEMBLVEP.out.vcf_tbi
        annotation_summary = VCF_ANNOTATE_ENSEMBLVEP.out.reports
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(topic_versions.versions_file)
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'exomecnv_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }



    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)

    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))

    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))

    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'exomecnv'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    counts         = count_files
    cnv_call       = cnv_vcfs_created
    cnv_call_vep   = vep_vcfs
    vep_summary    = annotation_summary
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    multiqc_data   = MULTIQC.out.data.toList()   // channel: /path/to/multiqc_data/
    multiqc_plots  = MULTIQC.out.plots.toList()  // channel: /path/to/multiqc_plots/
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
