# Changelog

All notable changes to `mosaic-event-circos` are recorded here.

## Unreleased

- Added fully synthetic three-type and four-type example mosaic event files for testing.
- Added `scripts/generate_synthetic_example_data.R` to regenerate the synthetic examples.
- Updated the README to use `example_output/synthetic.3types.default.png` as the primary example figure.
- Updated the Quick Start and example-output documentation to use the synthetic three-type dataset.
- Removed README references to the older cohort-derived bundled example dataset.

## v1.1.0 - 2026-07-17

- Added optional support for MoChA `Undetermined` events as a fourth track.
- Added explicit gray tile, border, and alpha-background colors for `Undetermined`.
- Fixed color-name handling for custom event types supplied through `--types`.
- Updated documentation for optional event type selection and track ordering.
- Added root-level repository metadata files: `VERSION`, `LICENSE`, `CITATION.cff`, `.gitignore`, and `CHANGELOG.md`.

## v1.0.0 - 2026-05-17

- Initial public GitHub release.
- Added R/circlize circos plotting script for autosomal mosaic events.
- Added default event tracks for `Gain`, `CN-LOH`, and `Loss`.
- Added automatic lane assignment so overlapping events are drawn in separate radial lanes.
- Added automatic track-height scaling with equal tile height across event types.
- Added support for GRCh38/hg38 and GRCh37/hg19 coordinate columns.
- Added light alpha-colored track backgrounds and stronger event tiles.
- Added example PLCO subset data and example output.
