# nf-cmgg/exomecnv: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v2.1.1

- Re-added the `genome` parameter to `nextflow.config` as it's needed by other configs.

## v2.1.0 Jewel Jashari [2026-05-28]

### `New features`

- Added `--splitx` parameter to split the regions of interest bed file into autosomal and chrX regions. This will make sure that the calling happens once for autosomes and once for chrX.
- Added `--roi_sheet` parameter to provide ROI BED files for each batch. The `--roi` parameter will be used as default in case the batch isn't present in this file.

### `Changes`

- Bumped minimal Nextflow version to 26.04.0
- Moved the default configuration base to nf-cmgg/configs

### `Improvements`

- Migrated the pipeline to nf-core template v3.5.1
- Migrated the pipeline to workflow output definitions and thus bumping the minimal Nextflow version to 25.10.0
- Migrated the pipeline's version handling to topic channels.
- Migrated the pipeline to parameter types

## v2.0.2 Vintage Verthongen [2025-12-03]

### `Bug fixes`

- Fix vcf input handling in samplesheet processing
- The `sample` column is now the only required column when using VCF input
- Added `.cnvs` to the output files for Galaxy compatibility

## v2.0.1 Warrior Witsel [2025-10-07]

### `Bug fixes`

- add roi in `WES` config

## v2.0.0 Mindful Mertens [2025-09-04]

### `Improvements`

- Replace counting step with `mosdepth`: no more conversion to BAM files required :rocket:
- Allow `*.per-base.bed.gz` inputs, skipping bam/cram handling entirely.
- Bump modules to the latest versions
- Disable tests for previously tested nf-core modules
- Fix tests, migrate CI from `filter` to `tag` based scatter
- Deprecate use of split ROI files in favor of a single ROI file

## v1.2.2 Dynamic De Bruyne [2025-01-20]

### `Bug fixes`

- Fix `WES` config
- Fix file collision in `nextflow` config

## v1.2.1 Lunatic Lamkel Zé [2025-01-07]

### `Improvements`

- Added a `WES` profile to make it easier to run the pipeline on our infrastructure
- Pin the VEP version to v105

### `Bug Fixes`

- Fixed an issue where the bedgovcf yaml wasn't being given
- Added system env fetching for `--hook_url`

## v1.2.0 - Dominant De Ketelaere [2024-11-27]

### `Updates`

- Bumped the template to nf-core v3.0.2

### `Improvements`

- Refactored the whole pipeline and made some small improvements
- Removed a bottleneck in the exomedepth flow
- Samplesheet header: rename `pool` to `batch` ([issue/23](https://github.com/nf-cmgg/exomecnv/issues/23))

## v1.1.0 - Amazing Alderweireld [2024-11-19]

### `Improvements`

- `SAMTOOLS_CONVERT`: add optional output path for BAM files
- copy `samplesheet.csv` to output dir
- add pipeline testing with `nf-test`
- `bedgovcf` module config: add format field
- `exomedepth/merge_count` module: sort columns in summary file by sample names

### `Updates`

- Bumped modules `utils_nextflow_pipeline`, `bedgovcf`, `ensemblvep/vep`, `multiqc`, `tabix/tabix`and `samtools/convert` to the newest versions
- Upgraded `nf-core` to v3.0.2 template
- Upgraded `nextflow` version to 24.10.0

## v1.0.2 - Youthful Yamal [2024-07-10]

### `Fixes`

- `CNV_CALL_X`: fix input channel to "roi_chrx"
- allow sample numbers as sample names

## v1.0.1 - Lightning Lukaku [2024-06-19]

### `Improvements`

- Index the VEP annotated VCF with TABIX
- Do not copy output of SAMTOOLS_CONVERT module (BAM files) to the `publishDir`
- update versions of multiqc and samtools_convert modules
- optimize module resources

### `Fixes`

- Sort file of merged CNV calls to fix an issue with TABIX (needs sorted VCF files)

## v1.0.0 - Dashing Doku - [2024-06-12]

Initial release of nf-cmgg/exomecnv, created with the [nf-core](https://nf-co.re/) template v2.13.

### `Added`

- First release of the pipeline - CNV calling using [ExomeDepth](https://github.com/vplagnol/ExomeDepth)
