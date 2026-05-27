#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-cmgg/exomecnv
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-cmgg/exomecnv
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
//  use getGenomeAttribute() to fetch parameters
//  from igenomes.config using `--genome`
include { getGenomeAttribute      } from './subworkflows/local/utils_nfcore_exomecnv_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { EXOMECNV                } from './workflows/exomecnv'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_exomecnv_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_exomecnv_pipeline'

/*

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
params {

    // Path to comma-separated file containing information about the samples in the experiment.
    input: Path

    // Path to comma-separated file containing information about the regios of interest per batch/pool/group in the experiment.
    roi_sheet: Path?

    // The output directory where the results will be saved. You have to use absolute paths to storage on Cloud infrastructure.
    outdir: Path

    // Email address for completion summary.
    email: String?

    // MultiQC report title. Printed as page header, used for filename if not otherwise specified.
    multiqc_title: String?

    // Option to execute the ExomeDepth tool
    exomedepth: Boolean = true

    // Option to annotate the ExomeDepth VCFs and input VCFs with VEP
    annotate: Boolean = false

    // Run ExomeDepth separately for autosomal and chrX regions
    splitx: Boolean = false

    // Name of iGenomes reference.
    genome: String = 'GRCh38'

    // Path to FASTA genome file.
    fasta: Path = getGenomeAttribute('fasta')

    // Path to FASTA genome index file.
    fai: Path = getGenomeAttribute('fai')

    // The default ROI BED file to be used when no file is linked to a batch in the --roi_sheet file.
    roi: Path? = getGenomeAttribute('roi')

    // Display version and exit.
    version: Boolean = false

    // Email address for completion summary, only when pipeline fails.
    email_on_fail: String?

    // Send plain-text email instead of HTML.
    plaintext_email: Boolean = false

    // File size limit when attaching MultiQC reports to summary emails.
    max_multiqc_email_size: String = '25.MB'

    // Do not use coloured log outputs.
    monochrome_logs: Boolean = false

    // Incoming hook URL for messaging service
    hook_url: String?

    // Custom config file to supply to MultiQC.
    multiqc_config: Path?

    // Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file
    multiqc_logo: Path?

    // Custom MultiQC yaml file containing HTML including a methods description.
    multiqc_methods_description: Path?

    // Boolean whether to validate parameters against the schema at runtime
    validate_params: Boolean = true

    // Validation of parameters fails when an unrecognised parameter is found.
    pipelines_testdata_base_path: String?

    // Display the help message.
    help = false

    // Display the full detailed help message.
    help_full: Boolean = false

    // Display hidden parameters in the help message (only works when --help or --help_full are provided).
    show_hidden: Boolean = false

    // Cache version
    vep_cache_version: Integer = 105

    // Species
    species: String = 'homo_sapiens'

    // Path to the VEP cache
    vep_cache: Path? = getGenomeAttribute('vep_cache')

    // Genome
    vep_assembly: String = 'GRCh38'
}

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        args,
        params.outdir,
        params.input,
        params.help,
        params.help_full,
        params.show_hidden,
        params.roi,
        params.roi_sheet,
    )

    //
    // WORKFLOW: Run main workflow
    //

    EXOMECNV (
        // file inputs
        PIPELINE_INITIALISATION.out.samplesheet,
        PIPELINE_INITIALISATION.out.rois,
        params.outdir,
        params.fasta,
        params.fai,
        params.vep_cache,
        file("${projectDir}/assets/exomedepth.yaml", checkIfExists:true),
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.roi,

        // booleans
        params.exomedepth,
        params.annotate,
        params.splitx,

        // strings
        params.vep_assembly,
        params.species,

        // integers
        params.vep_cache_version
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        EXOMECNV.out.multiqc_report
    )

    publish:
    counts = EXOMECNV.out.counts
    cnv_call = EXOMECNV.out.cnv_call
    cnv_call_vep = EXOMECNV.out.cnv_call_vep
    vep_summary = EXOMECNV.out.vep_summary
    multiqc_report = EXOMECNV.out.multiqc_report
    multiqc_data = EXOMECNV.out.multiqc_data
    multiqc_plots = EXOMECNV.out.multiqc_plots

}

output {
    counts {
        path "exomedepth/counts/"
    }
    cnv_call {
        path "exomedepth/cnv_call/"
    }
    cnv_call_vep {
        path "exomedepth/cnv_call_vep/"
    }
    vep_summary {
        path "exomedepth/cnv_call_vep/"
    }
    multiqc_report {
        path "multiqc/"
    }
    multiqc_data {
        path "multiqc/"
    }
    multiqc_plots {
        path "multiqc/"
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
