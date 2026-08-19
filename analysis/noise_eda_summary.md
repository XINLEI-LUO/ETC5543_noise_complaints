# Noise Sensor Exploratory Data Analysis

> **Purpose:** Provide a clear preliminary assessment of the Melbourne microclimate noise-sensor data, identify the most reliable descriptive patterns, and document important data-quality and coverage limitations before deeper modelling.

---

## Executive summary

The dataset contains **975,550 observations** from **12 devices** between **31 May 2022 and 17 August 2026**. Of these, **893,959 observations have valid noise values**.

### Main takeaways

- **A clear daily cycle is present.** Median noise is lowest around **03:00 (61.6)** and highest around **15:00 (69.7)**.
- **Day-of-week differences are small.** Friday has the highest pooled median (**68.3**) and Sunday the lowest (**67.3**), only **1.0 dataset unit apart**.
- **Sensor-level differences are substantial.** Median noise ranges from **52.3** at `ICTMicroclimate-01` to **81.1** at `ICTMicroclimate-10`.
- **The apparent early time-series jump should not be interpreted as a real city-wide trend.** It was strongly affected by a **158-day data gap** and changing sensor composition.
- **Missing noise is concentrated in a small number of devices.** `aws5-0999` has **100% missing noise**, while `ICTMicroclimate-01` has **10.52% missing**.
- The monitoring network is **sparse and centrally located**, so the current data do **not** support city-wide hotspot claims.

> **Important:** The official data source does not document the unit or interpretation of `Noise`. All numerical results below therefore use **dataset units**.

---

## 1. What was done

After downloading the raw `microclimate_sensors.csv` file, the preliminary EDA:

1. inspected the dataset structure, variable types, date range, sensors, locations, and coordinates;
2. checked duplicates, missing values, zero noise readings, and extreme values;
3. parsed timestamps and assessed the observation frequency of each sensor;
4. compared noise patterns by **time of day**, **day of week**, **weekday/weekend**, and **sensor**;
5. examined sensor coverage over time to identify outages and changing network composition;
6. assessed spatial coverage using sensor coordinates;
7. ran balanced/equal-sensor sensitivity checks to determine whether the main temporal findings were robust;
8. reviewed which proposed research questions can and cannot be answered using the current dataset alone.

No suspicious observations were automatically deleted at this stage.

---

## 2. Dataset at a glance

| Item | Summary |
|---|---|
| Raw observations | **975,550** |
| Raw variables | **16** |
| Date range | **31 May 2022 – 17 August 2026** |
| Device IDs | **12** |
| Location labels | **11** |
| Distinct coordinate pairs | **12** |
| Valid noise observations | **893,959** |
| Missing noise | **81,591 (8.36%)** |
| Overall noise median | **67.9** |
| Approximate sampling frequency | **15 minutes** |

The main fields used in this analysis are:

- `Noise` — measurement field;
- `Time` — timestamp;
- `Device_id` — sensor identifier;
- `SensorLocation` — location label;
- `LatLong` — coordinates.

The remaining numeric variables describe wind, temperature, humidity, atmospheric pressure, PM2.5, and PM10.

---

# 3. Main findings

## Finding 1 — Strong within-day pattern

The clearest temporal pattern is variation across the day.

- Pooled median noise is lowest at **03:00: 61.6**.
- It rises to **69.7 at 15:00**.
- The difference is **8.1 dataset units**.

The equal-sensor sensitivity analysis gives the same overall conclusion: the sensor-standardised median is lowest at **03:00 (58.9)** and highest at **15:00–16:00 (70.5)**.

**Interpretation:** noise measurements are generally lower overnight and higher during the daytime and afternoon. This is a descriptive pattern only; the current analysis does not establish a causal explanation.

**Relevant output:** Figure 2 and the hourly summary.

---

## Finding 2 — Little difference across weekdays

Day-of-week differences are much smaller than the within-day variation.

| Day comparison | Pooled median |
|---|---:|
| Friday | **68.3** |
| Sunday | **67.3** |
| Difference | **1.0** |

The pooled weekday median is **68.1**, compared with **67.6** on weekends.

The equal-sensor analysis also preserves the overall ordering, with Friday highest and Sunday lowest, although the standardised Friday–Sunday difference is slightly larger.

**Interpretation:** there is no strong evidence from this descriptive analysis that Monday-to-Sunday noise levels differ dramatically.

**Relevant output:** Figure 3 and the weekday / weekday-weekend summaries.

---

## Finding 3 — Sensors record noticeably different levels

Median noise differs substantially across monitored sensors.

- Lowest median: **52.3** at `ICTMicroclimate-01`
- Highest median: **81.1** at `ICTMicroclimate-10`

This difference is much larger than the pooled day-of-week difference.

**Interpretation:** some monitored sites record consistently higher or lower values, but these should **not** automatically be interpreted as Melbourne-wide “hotspots”. Sensor calibration, siting, coverage dates, missingness, and local context may contribute to the differences.

**Relevant output:** Figure 4 and the sensor coverage table.

---

## Finding 4 — Long-term pooled trends are composition-sensitive

The original time-series plot created an apparently dramatic increase in 2022 because it connected observations across a **158-day gap**.

After missing calendar days were inserted and the line was broken:

- only sensor 01 contributes on 2–3 June 2022;
- there are then **157 calendar days with no valid noise observations**;
- sensor 02 appears on 8 November with only eight valid observations;
- additional sensors enter gradually through 2023 and 2024.

A balanced sensitivity analysis using `ICTMicroclimate-01`, `ICTMicroclimate-02`, and `ICTMicroclimate-03` from **1 January 2023 to 30 June 2026** produced:

- **148 complete weeks**;
- correlation with the original pooled weekly series: **0.82**;
- median absolute difference: **1.4 dataset units**.

**Interpretation:** some broad temporal movements remain after equal weighting, but individual levels and peaks depend on which sensors are active. The pooled series should therefore be treated as a **descriptive monitored-network series**, not as a city-wide noise trend.

**Relevant output:** Figures 1 and 6.

---

## Finding 5 — Missingness is concentrated

The overall missing-noise rate is **8.36%**, but it is not evenly distributed.

- `aws5-0999`: **65,847 observations and 100% missing noise**
- `ICTMicroclimate-01`: **10.52% missing noise**
- every other ICT sensor: **below 0.63% missing noise**

There are also **649 exact zero noise readings**. These have been retained because the available metadata do not establish whether zero represents a genuine measurement, dropout, or fault code.

**Interpretation:** missingness and zero values should be investigated before applying any exclusion rule.

---

# 4. Spatial coverage

All 12 devices have coordinates, although `aws5-0999` has no usable noise values.

The sensors cover only a **small set of central Melbourne monitored sites**. Two devices, `ICTMicroclimate-10` and `ICTMicroclimate-11`, share the generic location label **“1 Treasury Place”** but have slightly different coordinates.

Therefore:

> Figure 5 should be interpreted as a **sensor-location map**, not as a Melbourne-wide noise surface.

The current spatial coverage is insufficient for strong claims about where Melbourne's overall noise hotspots are located.

---

# 5. Data-quality notes

## Core checks

| Check | Result | Interpretation |
|---|---:|---|
| Exact duplicated raw rows | 0 | No exact duplicates found |
| Missing device ID | 0 | Complete |
| Missing timestamp | 0 | Complete |
| Missing location label | 0 | Complete |
| Missing coordinates | 0 | Coordinates parsed successfully |
| Missing noise | 81,591 (8.36%) | Concentrated in a small number of devices |
| Valid noise | 893,959 | Used in summaries |
| Noise mean / SD | 66.23 / 11.33 | Pooled across sensors and times |
| Noise min / median / max | 0.0 / 67.9 / 131.1 | Unit unverified |
| Q1 / Q3 | 58.5 / 71.6 | IQR = 13.1 |
| 1st / 99th percentile | 45.4 / 96.2 | Long upper tail and low readings |
| Outside 1.5-IQR fences | 25,989 (2.91%) | Flagged, not deleted |
| Exact zero readings | 649 | Require metadata review |

The CSV also begins with a UTF-8 byte-order mark and uses ISO timestamps with colon-separated UTC offsets. These were handled explicitly without altering the raw file.

---

# 6. Sampling frequency and temporal coverage

For each sensor, the median successive positive time gap is approximately **15 minutes (15.02–15.27 minutes)**.

For the 11 ICT devices, **92.2%–99.7%** of gaps fall between 12 and 18 minutes. For `aws5-0999`, only **63.7%** do, and its upper-quartile gap is **30.13 minutes**.

This means the intended frequency appears to be approximately 15 minutes, but outages and irregular gaps occur.

### Sensor coverage

| Device | First | Last | Observations | Valid noise | Missing noise | Median |
|---|---|---|---:|---:|---:|---:|
| ICTMicroclimate-01 | 2022-05-31 | 2026-07-01 | 138,143 | 123,609 | 10.52% | 52.3 |
| ICTMicroclimate-02 | 2022-11-08 | 2026-08-17 | 103,113 | 102,470 | 0.62% | 70.0 |
| ICTMicroclimate-03 | 2022-12-21 | 2026-08-17 | 118,786 | 118,679 | 0.09% | 70.2 |
| ICTMicroclimate-04 | 2023-08-04 | 2025-07-29 | 52,573 | 52,565 | 0.02% | 67.0 |
| ICTMicroclimate-05 | 2023-08-04 | 2026-08-17 | 81,424 | 81,371 | 0.07% | 69.7 |
| ICTMicroclimate-06 | 2023-12-11 | 2026-08-17 | 81,910 | 81,889 | 0.03% | 63.0 |
| ICTMicroclimate-07 | 2023-12-11 | 2026-08-17 | 82,145 | 82,115 | 0.04% | 63.6 |
| ICTMicroclimate-08 | 2023-12-11 | 2026-08-17 | 81,479 | 81,455 | 0.03% | 69.9 |
| ICTMicroclimate-09 | 2023-12-11 | 2026-08-09 | 67,182 | 67,156 | 0.04% | 60.6 |
| ICTMicroclimate-10 | 2024-08-13 | 2026-08-17 | 51,032 | 50,886 | 0.29% | 81.1 |
| ICTMicroclimate-11 | 2024-08-13 | 2026-08-17 | 51,916 | 51,764 | 0.29% | 53.4 |
| aws5-0999 | 2022-12-15 | 2026-08-17 | 65,847 | 0 | 100.00% | NA |

Hourly and weekday summaries are well supported by large sample sizes. Longer month, season, and year comparisons require greater caution because sensors enter and leave the network at different times. **2026 is also only a partial year.**

---

# 7. Robustness checks

## Equal-sensor hourly pattern

Equal weighting preserves the strong daily cycle:

- standardised minimum: **58.9 at 03:00**
- standardised maximum: **70.5 at 15:00–16:00**
- maximum hour-specific difference between pooled and standardised summaries: **2.7 units**

The daily-cycle conclusion is robust.

## Equal-sensor weekday pattern

Equal weighting also preserves the conclusion that weekday differences are relatively small:

- standardised Sunday median: **65.2**
- standardised Friday median: **67.95**
- maximum day-specific pooled-versus-standardised difference: **2.1 units**

Friday remains highest and Sunday remains lowest.

## Balanced weekly series

Using the same three early sensors over a shared period:

- sensors: `ICTMicroclimate-01`, `ICTMicroclimate-02`, `ICTMicroclimate-03`
- period: **1 January 2023 – 30 June 2026**
- complete weeks retained: **148**
- balanced vs pooled correlation: **0.82**
- median absolute difference: **1.4 units**
- balanced range: **62.0–71.7**
- pooled range: **62.5–71.1**

This supports the existence of some shared temporal patterning while confirming that pooled levels remain sensitive to sensor composition.

---

# 8. What can the current dataset answer?

| Research question | Status | Key limitation |
|---|---|---|
| How does measured noise vary by time of day? | **Answerable now** | Unequal sensor coverage |
| How does measured noise vary by day of week? | **Answerable now** | Unadjusted for holidays/network changes |
| How does measured noise vary over longer periods? | **Partially answerable** | Sensors enter/leave; 2026 incomplete |
| Which monitored sensors record relatively high noise? | **Answerable now** | Not a clean location-only comparison |
| Where are Melbourne's noise hotspots? | **Not currently answerable** | Spatial network is too sparse |
| Are nightlife-heavy areas noisier? | **Not currently answerable** | No nightlife/activity variables |
| Are quieter areas well served by restaurants/entertainment? | **Not currently answerable** | Requires amenity/accessibility data |
| Are noise levels related to complaints? | **Not currently answerable** | No complaint dataset is currently linked |

---

# 9. Important limitations

1. The **unit and interpretation of `Noise` are not documented** in the supplied dataset.
2. Sensor calibration and noise-specific quality flags are unavailable.
3. Sensors have **unequal observation periods** and enter/leave the network at different times.
4. The spatial network is sparse and cannot represent all of Melbourne.
5. Zero and extreme values have been flagged but not removed because their meaning is unknown.
6. Results are **descriptive associations**, not causal findings.

---

# 10. Recommended next steps

1. Obtain authoritative metadata for the `Noise` unit, sensor model, calibration, quality flags, and zero/missing-value conventions.
2. Investigate outages and the **649 zero readings** before defining exclusion rules.
3. Keep balanced and equal-sensor summaries alongside pooled results in future reporting.
4. Agree on the descriptive research questions before adding external datasets.
5. If the project expands to nightlife, amenities, complaints, or Melbourne-wide hotspot analysis, acquire the corresponding external spatial datasets.

---

## Technical note on the `Noise` field

The supplied file does not document the meaning or unit of `Noise`. The City of Melbourne's current official schema labels `Noise` as a decimal field without a unit or description, and the older microclimate data dictionary contains no noise entry.

For this reason, the report deliberately uses the term **dataset units** rather than assuming that the values are decibels.

---

*This document is a preliminary EDA summary. Findings may be refined after sensor metadata, quality information, and additional project requirements are confirmed.*
