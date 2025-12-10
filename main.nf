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

params.fasta     = getGenomeAttribute('fasta')
params.fai       = getGenomeAttribute('fai')
params.vep_cache = getGenomeAttribute('vep_cache')
params.roi       = getGenomeAttribute('roi')

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
        "${projectDir}/assets/exomedepth.yaml",
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
        params.hook_url,
        EXOMECNV.out.multiqc_report
    )

    publish:
    counts = EXOMECNV.out.counts
    cnv_call = EXOMECNV.out.cnv_call
    cnv_call_vep = EXOMECNV.out.cnv_call_vep
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
