/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ENSEMBLVEP_VEP as         VEP           } from '../../../modules/nf-core/ensemblvep/vep/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENSEMBLE VEP WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ENSEMBLVEP {

    take:

    ch_vcfs
    fasta
    vep_cache

    main:

    ch_vep_extra_files = []

    VEP (
        ch_vcfs,
        params.vep_assembly,
        params.species,
        params.vep_cache_version,
        vep_cache,
        fasta,
        ch_vep_extra_files
    )

    emit:
    vcfs = VEP.out.vcf
    versions = VEP.out.versions
}
