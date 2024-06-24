/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ENSEMBLVEP_VEP as         VEP           } from '../../../modules/nf-core/ensemblvep/vep/main'
include { TABIX_TABIX as TABIX_VEP                      } from '../../../modules/nf-core/tabix/tabix/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENSEMBLE VEP WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VCF_ANNOTATION {

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

    // Index VCF file

    TABIX_VEP ( VEP.out.vcf )

    emit:
    vcfs = VEP.out.vcf
    tbi = TABIX_VEP.out.tbi
    versionsvep = VEP.out.versions
    versionstbi = TABIX_VEP.out.versions
}
