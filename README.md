<img src="docs/images/nfcore-exomecnv_logo.png" width="500">

[![GitHub Actions CI Status](https://github.com/nf-cmgg/exomecnv/actions/workflows/ci.yml/badge.svg)](https://github.com/nf-cmgg/exomecnv/actions/workflows/ci.yml)
[![GitHub Actions Linting Status](https://github.com/nf-cmgg/exomecnv/actions/workflows/linting.yml/badge.svg)](https://github.com/nf-cmgg/exomecnv/actions/workflows/linting.yml)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/nf-cmgg/exomecnv)

## Introduction

**nf-cmgg/exomecnv** is a bioinformatics pipeline that can be used to call copy number variations (CNVs) from exome sequencing data with ExomeDepth and annotate these with EnsemblVEP. It takes a samplesheet with CRAM or BAM files and their index files as input, generates read count data, calls CNVs and ends with an annotation. It is also possible to take a samplesheet with VCF files and their index files as input and only execute the annotation.

## Pipeline Summary

1. Input samplesheet check
2. Convert CRAM to BAM if CRAM files are provided (optional)
3. ExomeDepth counting per sample (autosomal and chrX are separated)
4. Merge count files per pool (autosomal and chrX remain separated)
5. ExomeDepth CNV calling per sample (autosomal and chrX remain separated)
6. Merge CNV calling files per sample (autosomal and chrX are merged)
7. Convert merged files to VCF
8. Generate index files for these VCF files
9. Annotate VCF files with EnsemblVEP

<img src="Exomedepth2.png" width="500">

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

First, prepare a samplesheet with your input data that looks as follows:

`samplesheet.csv`:

```csv
sample,pool,family,cram,crai,vcf,tbi
sample1,poolM,Fam1,/path/to/sample1.cram,/path/to/sample1.crai
sample2,poolF,Fam2,/path/to/sample2.cram,/path/to/sample2.crai,/path/to/sample2.vcf,/path/to/sample2.vcf.tbi
```

Each row represents a sample with the associated pool and family, followed by the optional paths to the CRAM/CRAI and/or VCF/TBI files, depending on which tasks should be executed.

Now, you can run the pipeline using:

```bash
nextflow run nf-cmgg/exomecnv \
   -profile <docker/conda> \
   --input /path/to/samplesheet.csv \
   --outdir /path/to/outdir \
   --vep_cache /path/to/vep_cache \
   --exomedepth \
   --annotate
```

to execute the ExomeDepth workflow, followed by an EnsemblVEP annotation on CRAM/CRAI (or BAM/BAI) files provided in the samplesheet. The --annotate parameter is optional. If not provided, only the ExomeDepth workflow will be executed.
It is also possible to run the pipeline using:

```bash
nextflow run nf-cmgg/exomecnv \
   -profile <docker/conda> \
   --input /path/to/samplesheet.csv \
   --outdir /path/to/outdir \
   --vep_cache /path/to/vep_cache
```

to skip the ExomeDepth workflow and only execute the EnsemblVEP annotation on VCF/TBI files provided in the samplesheet.

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Credits

nf-cmgg/exomecnv was originally written by [BertGalle](https://github.com/BertGalle) and [Toros](https://github.com/ToonRosseel).

We thank the following people for their extensive assistance in the development of this pipeline: [nvnieuwk](https://github.com/nvnieuwk)

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use nf-cmgg/exomecnv for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
