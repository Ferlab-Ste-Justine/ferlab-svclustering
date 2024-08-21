# Introduction

**ferlab/svclustering** is a bioinformatics pipeline designed to cluster Copy Number Variants (CNVs), specifically duplications and deletions, across individuals using the SVCluster functionality from GATK. This tool aids in the analysis of structural variations, providing insights into genetic differences at the population level.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) to set up Nextflow.

<!-- TODO
Before running the workflow on actual data, [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with the `-profile test` command. -->

### Preparing Your Input

Before running the pipeline, you need to prepare a samplesheet that contains the necessary information about your input data. This samplesheet should include the following mandatory columns:

- **sample**: A unique identifier for each sample (e.g., sample name, sample ID).
- **familyId**: An identifier for the family to which the sample belongs (e.g., trios, duos). If your sample is not associated with a family, use a placeholder (e.g., **F12345**).
- **vcf**: The full path to the VCF file.

Example samplesheet:

```csv
sample,familyId,vcf
28210,F1,samples/28210.cnv.vcf.gz
28226,F1,samples/28226.cnv.vcf.gz
28227,F1,samples/28227.cnv.vcf.gz
28240,F2,samples/28240.cnv.vcf.gz
28221,F2,samples/28221.cnv.vcf.gz
28222,F2,samples/28222.cnv.vcf.gz
```

## Running the Pipeline

To execute the pipeline, use the following command:

```bash
nextflow run ferlab/svclustering \
   -profile <docker/singularity/.../institute> \
   --input samplesheet.csv \
   -c nextflow.config \
   --outdir <OUTDIR> \
   <Mandatory Params>
```

> [!RECOMENDED] Alternatively, you can specify a parameter file and run the pipeline using:

```bash
nextflow run ferlab/svclustering \
   -profile <docker/singularity/.../institute> \
   -c nextflow.config \
   -params-file nf-params.json
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;
> see [docs](https://nf-co.re/usage/configuration#custom-configuration-files).

## Mandatory Parameters

Here are the mandatory parameters you need to specify with **-params-file** or **CLI**:

    •	input: Path to the samplesheet.csv file.
    •	outdir: Path to the output directory.
    •	fasta: Path to the reference genome FASTA file.
    •	fasta_fai: Path to the reference genome FAI file.
    •	fasta_dict: Path to the reference genome dictionary file.

Example nf-params.json:

```json
{
  "input": "samplesheet.csv",
  "outdir": "results",
  "fasta": "refgenomes/hg38/Homo_sapiens_assembly38.fasta",
  "fasta_fai": "refgenomes/hg38/Homo_sapiens_assembly38.fasta.fai",
  "fasta_dict": "refgenomes/hg38/Homo_sapiens_assembly38.dict"
}
```

## Credits

ferlab/svclustering was originally written by David Morais.

Special thanks to the following individuals for their extensive contributions to the development of this pipeline:

Felix-Antoine Le Sieur

Alexandre Dione

Damien Geneste

Lysisane Bouchard

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
