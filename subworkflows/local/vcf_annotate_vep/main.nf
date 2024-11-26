/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ENSEMBLVEP_VEP as VEP     } from '../../../modules/nf-core/ensemblvep/vep/main'
include { TABIX_TABIX as TABIX_VEP  } from '../../../modules/nf-core/tabix/tabix/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ENSEMBLE VEP WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow VCF_ANNOTATE_VEP {

    take:
    ch_vcfs
    fasta
    vep_cache
    vep_assembly
    species
    vep_cache_version

    main:
    def ch_vep_extra_files  = []
    def ch_versions         = Channel.empty()

    VEP(
        ch_vcfs,
        vep_assembly,
        species,
        vep_cache_version,
        vep_cache,
        fasta,
        ch_vep_extra_files
    )
    ch_versions = ch_versions.mix(VEP.out.versions.first())
    // Index VCF file

    TABIX_VEP( VEP.out.vcf )
    ch_versions = ch_versions.mix(TABIX_VEP.out.versions.first())

    emit:
    vcfs        = VEP.out.vcf
    tbi         = TABIX_VEP.out.tbi
    versions    = ch_versions
}
