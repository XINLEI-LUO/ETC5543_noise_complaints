# CLUE Business Integration Summary

## Purpose and status

This extension adds a broader 2024 business and land-use context to the existing sensor-level noise integration. It distinguishes general urban activity and business composition from the existing nightlife-specific bar, patron-capacity and restaurant-seating measures. The workflow is descriptive and exploratory; it does not support causal claims.

The extension completed successfully. It created 33 unique `device_id + buffer_m` rows for 11 noise sensors at 250 m, 500 m and 1,000 m. It did not overwrite the validated integration outputs.

## Source, period and generation

- Source: `data/raw/business-establishments-with-address-and-industry-classification.csv`, City of Melbourne CLUE business establishments.
- Analysis period: Census year 2024 only.
- Generation script: `analysis/prepare_clue_business_features.R`.
- Validation script: `analysis/validate_sensor_integration.R`.
- Primary output: `data/processed/clue_business_features_by_buffer.csv`.
- Extended integration: `data/processed/integrated_sensor_all_buffers_with_clue_2024.csv`.
- QA output: `data/processed/clue_business_integration_qa.csv`.
- Duplicate sensitivity output: `data/processed/clue_business_duplicate_sensitivity.csv`.

## Dataset structure

The source contains 413,550 rows and 12 columns covering Census years 2002 through 2024. The 2024 subset contains 19,672 records: 14,337 active-business records and 5,335 records classified as `Vacant Space`. All 2024 rows contain longitude, latitude and the text-form `Point` field. The coordinates are within plausible Melbourne bounds.

The dataset contains property, base-property and block identifiers but no explicit establishment identifier. A property can contain multiple businesses, so property or address identifiers are not treated as business identifiers.

## Spatial linkage

Longitude and latitude are interpreted as WGS84 coordinates (EPSG:4326). Business points and the validated noise-sensor locations are transformed to GDA2020 / MGA Zone 55 (EPSG:7855). The script reuses the existing noise-sensor coordinates and constructs the same 250 m, 500 m and 1,000 m circular buffers used by the established integration workflow.

Spatial matching uses point containment within each buffer. A business may be counted for more than one noise sensor where buffers overlap. This is expected and does not represent duplicate source records.

The analysis unit remains one noise sensor by one buffer distance. The 500 m specification is primary; 250 m and 1,000 m are sensitivity distances.

## ANZSIC classification strategy

Detailed features use explicit ANZSIC4 classes or published ANZSIC division ranges. Business-mix entropy uses 19 mutually exclusive ANZSIC divisions, A through S. `Vacant Space` has code 0, is not an ANZSIC activity division and is excluded from active-business totals and entropy.

The detailed food and hospitality fields are:

- `cafes_restaurants`: ANZSIC4 4511.
- `takeaway_food`: ANZSIC4 4512.
- `pubs_bars_clue`: ANZSIC4 4520.
- `other_food_beverage`: other codes from 4500 to 4599 after excluding 4511, 4512 and 4520.
- `accommodation_businesses`: ANZSIC4 4400.

Retail, professional, finance, real-estate, administrative-support, and arts-and-recreation fields use their documented ANZSIC division ranges. The exact mappings are recorded in `analysis/clue_business_feature_dictionary.md` and in the preparation script.

## Business-mix methodology

For each sensor buffer, entropy is:

`H = -sum(p_k * log(p_k))`

where `p_k` is the proportion of active business records in ANZSIC division `k`. Normalised entropy is `H / log(19)`, using the fixed set of 19 possible divisions so values are comparable between buffers.

Confirmed zero-business buffers would receive zero counts, zero density and zero entropy rather than missing values. `NA` is reserved for unavailable input or unresolved linkage. No observed buffer has zero active businesses or fewer than 10 active businesses, so entropy sparsity flags are false throughout this output.

## Main descriptive results

| Buffer | Sensors | Active businesses minimum | Median | Maximum | Normalised entropy range |
|---:|---:|---:|---:|---:|---:|
| 250 m | 11 | 13 | 264 | 862 | 0.292–0.795 |
| 500 m | 11 | 48 | 1,087 | 3,616 | 0.528–0.833 |
| 1,000 m | 11 | 181 | 4,320 | 7,502 | 0.761–0.818 |

Business density uses the nominal circular-buffer area, `pi * radius^2`, expressed in square kilometres. It is not adjusted for water, roads, municipal boundaries or developable land.

## Duplicate-record decision

There are no exact duplicate 2024 rows. One group of three records shares trading name, address, ANZSIC4 code and coordinates, creating two candidate excess records. The rows have different property IDs and therefore are not silently removed from the primary data.

The sensitivity version retains one record for each trading-name, address, ANZSIC4 and coordinate combination. The candidate group falls outside all analysed sensor buffers, so all 33 active-business counts and normalised entropy values are unchanged. The primary output therefore retains the source records.

## Integration and QA

The CLUE features are joined to the existing 33-row integration using `device_id + buffer_m` with one-to-one key validation. The row count and complete key set are unchanged. All 18 automated CLUE checks pass, including year restriction, coordinate validity, key uniqueness, buffer membership, non-negative integer counts, count monotonicity, entropy bounds, density bounds and sensitivity diagnostics.

## Recommended analytical use

Primary exploratory variables are `total_active_businesses`, `business_density_per_km2`, the major food, retail, accommodation, entertainment and professional categories, and normalised business-mix entropy. These fields help distinguish nightlife-dominated, restaurant-dominated, retail, office-oriented and mixed-business environments with similar total activity.

Financial, real-estate, administrative-support, vacancy and category-share measures are useful secondary descriptors. The CLUE pub count should not replace the existing bar count and patron-capacity variables; it is mainly a classification cross-check because the specialised nightlife source contains more directly relevant information.

Given only 11 noise sensors, modelling should use a small, pre-specified set of predictors. Highly correlated totals, densities, category counts and proportions should not be entered together without a clear diagnostic and substantive rationale.

## Limitations

CLUE records represent the 2024 Census snapshot, not continuous operation throughout the year. Non-vacant records are treated as active establishments for feature construction, but the source contains no separate operating-status or opening-hours field. Record counts are establishments in the source rather than verified unique corporate entities. Overlapping buffers legitimately reuse businesses across sensors. The sensor network is small and spatially concentrated, and associations cannot be interpreted as causal or city-wide effects.
