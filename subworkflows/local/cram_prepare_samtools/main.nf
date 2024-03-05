
// Convert CRAM files (optional)
include { SAMTOOLS_CONVERT as CRAM_TO_BAM  } from '../../../modules/nf-core/samtools/convert/main'
// include { SAMTOOLS_INDEX     } from '../../../modules/nf-core/samtools/index/main'

workflow CRAM_PREPARE_SAMTOOLS {

    take:
    ch_cram // channel: [mandatory] [ val(meta), path(cram), path(crai) ] => sample CRAM files and their indices
    fasta   // channel: [mandatory] fasta
    fasta_fai   // channel: [mandatory] fasta_fai

    main:

    ch_versions = Channel.empty()

    //
    // convert CRAM files to BAM files
    //
    CRAM_TO_BAM(ch_cram, fasta, fasta_fai)
    ch_versions = ch_versions.mix(CRAM_TO_BAM.out.versions)

    emit:
    bam      = CRAM_TO_BAM.out.alignment_index           // channel: [ val(meta), [ bam ], [bai] ]

    versions = ch_versions                     // channel: [ versions.yml ]
}

