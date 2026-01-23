# ferlab/svclustering: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

## [v1.3.5] - 2026-01-23

### `Fixed`
- [#13](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/13) Fix ALGORITHMS not being added to INFO field when column starts with END.

## [v1.3.4] - 2025-11-25

### `Changed`
- [#12](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/12) output filenames now dynamically reflect the clustering algorithm and reciprocal overlap threshold

## [v1.3.3] - 2025-11-18

### `Changed`
- [#11](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/11) Relax metric order assumptions in format column

## [v1.3.2] - 2025-08-26

### `Changed`
- [#9](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/9) Check PE header instead of CN when adding ECN header

## [v1.3.1] - 2025-04-23

### `Fixed`
- [#7](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/7) improve error handling in view_batch process

## [v1.3] - 2025-03-06

### `Added`
- [#5](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/5) introduce batch behaviour in filter step

### `Changed`

- [#4](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/4) avoid publishing intermediate outputs by default.

## [v1.2] - 2024-12-17

### `Changed`
- [#2](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/2) by default, only includes variants with FILTER column value of PASS.

## [v1.1] - 2024-08-21

### `Added`

- SVclustering workflow
- New Processes: Preprocessing, Svclusteringdup, Svclusteringdel
- Check input, and mandatory params
- Enabled moduleBinaries on config files
- Support for conda and docker

### `Changed`

- Samplesheet input method
- Schema_input.json fields
- [#1](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/1) invoke sample_preprocessing.py script through binary modules feature

### `Fixed`
- [#1](https://github.com/Ferlab-Ste-Justine/ferlab-svclustering/pull/1) fix typo for parameter clustering_algorithm in schema

### `Dependencies`

### `Deprecated`

## [v1.0dev]

Initial release of ferlab/svclustering, created with the [nf-core](https://nf-co.re/) template.

### `Added`

### `Fixed`

### `Dependencies`

### `Deprecated`
