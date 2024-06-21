# nf-cmgg/exomecnv: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0 - Dashing Doku - [2024-06-12]

Initial release of nf-cmgg/exomecnv, created with the [nf-core](https://nf-co.re/) template v2.13.

### `Added`

- First release of the pipeline - CNV calling using [ExomeDepth](https://github.com/vplagnol/ExomeDepth)

## v1.0.1 - Lightning Lukaku [2024-06-19]

### `Improvements`

- Index the VEP annotated VCF with TABIX
- Do not copy output of SAMTOOLS_CONVERT module (BAM files) to the `publishDir`

### `Fixes`

- Sort file of merged CNV calls to fix an issue with TABIX (needs sorted VCF files)

