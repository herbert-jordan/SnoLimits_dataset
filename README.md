# SnoLimits Dataset

A 500 m SWE and snow depth dataset for Colorado and California spanning the MODIS Satellite era (2001–2025).

This repository provides supporting files, figures, and scripts for the SnoLimits dataset. The dataset is generated using random forest models trained on lidar surveys and physiographic predictors, and is designed to support spatially and temporally continuous estimates of snowpack across the western United States.

---

## File Structure

### `example_workflow/`
Example scripts for creating the SnoLimits dataset end-to-end. Organized into sequential steps:

- `CO_SWE/` — Example workflow applied to Colorado SWE estimation
  - `s01_create_models/` — Scripts for training the random forest models using lidar-derived snow data and physiographic predictors
  - `s02_generate_masks/` — Scripts for generating spatial masks (e.g., open vs. forested areas, valid snow extent)
  - `s03_generate_test_data/` — Scripts for preparing holdout test data for model evaluation
  - `s04_6_simulate_aggregate/` — Scripts for running the trained models across the full domain and aggregating outputs to the final gridded product
- `functions/` — Shared utility functions used across workflow steps

---

### `inputs/`
Key input data and metadata required to run the workflow:

- `physiography/` — Raw physiographic predictor layers (e.g., elevation, slope, aspect, canopy cover, solar radiation)
- `snow_station/` — Snow station metadata and observations used for temporal validation
- `training_data/` — Sample training data derived from lidar surveys conducted prior to 2020. **Note:** Training data is restricted to NSIDC lidar surveys (pre-2020); ASO Inc. data is excluded due to more stringent data sharing requirements

---

### `figures/`
All figures and tables from the manuscript and supplementary materials:

- `manuscript_figures/` — Final publication-ready figures
- `snow_depth/` — Figures and error statistics for snow depth (supplementary; the manuscript focuses on SWE)
- `swe/` — Figures and error statistics for SWE across lidar survey domains
- `training_data_histograms/` — Histograms summarizing the distribution of training data used to fit the random forest models

---

### `validation/`
Results and reproducible workflows from spatial and temporal validation analyses:

- `spatial/` — Spatial (leave-one-basin-out) validation
  - `example_workflow/` — Scripts demonstrating the spatial validation procedure
  - `SD/` — Spatial validation results for snow depth
  - `SWE/` — Spatial validation results for SWE
- `temporal/` — Temporal (snow station) validation
  - `data/` — Processed data used in the temporal validation analysis
  - `example_workflow/` — Scripts demonstrating the temporal validation procedure
  - `plot_scripts/` — Scripts for generating temporal validation figures

---

## Validation Methods

**Spatial validation** is conducted using a leave-one-basin-out approach: lidar surveys from a given basin are withheld from both model training and prediction, and the model is re-trained on the remaining data. This tests the model's ability to generalize to unseen terrain and climatological regimes.

**Temporal validation** simulates SWE at pixels geographically closest to snow stations that were withheld from the training dataset. Modeled values are then compared against observed station records across the 2001–2025 period.

---

