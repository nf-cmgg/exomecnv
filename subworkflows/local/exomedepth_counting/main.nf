
// Convert CRAM files

workflow EXOMEDEPTH_COUNTING {

    take:
    ch_bam // channel: [mandatory] [ val(meta), path(bam), path(bai) ] => sample BAM files and their indices
    exon_target   // channel: [mandatory] [ val(meta), path(bed) ] 

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

