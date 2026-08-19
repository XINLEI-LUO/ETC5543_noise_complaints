# This folder contains the preliminary exploratory analysis for the **noise-pattern component** of our ETC5543 project.

## Research focus

The current overall project question is:

**How do urban noise levels and noise complaints vary across time and space in the City of Melbourne, and what characteristics of the urban environment are associated with these patterns?**

My current analysis focuses on the first part:

**How does recorded noise vary across time and monitored sensor locations?**

## Data source

The analysis uses the City of Melbourne Microclimate / IoT sensor CSV dataset:

[Microclimate sensors data](https://data.melbourne.vic.gov.au/explore/dataset/microclimate-sensors-data/)

The dataset contains approximately 15-minute observations from environmental sensors, including:

-   noise;
-   air temperature;
-   relative humidity;
-   atmospheric pressure;
-   wind speed and direction;
-   particulate matter; and
-   sensor coordinates.

The raw CSV is not stored in this repository because it is larger than GitHub's normal file-size limit.

To reproduce the analysis:

1.  Download the dataset from the official portal.
2.  Save it as:

``` text
data/raw/microclimate_sensors.csv
```

The analysis never overwrites the raw data.

## Important metadata limitation

The supplied CSV and currently available official schema do not document:

-   the measurement unit of `Noise`;

-   the noise sensor model;

-   calibration procedures;

-   noise-specific quality flags; or

-   the interpretation of zero values.

Noise values are therefore reported as **dataset units** rather than being assumed to represent decibels. Zero and extreme observations are flagged but not automatically removed.

## Reproducing the analysis

The complete analysis is implemented in:

```         
analysis/noise_eda.R
```

Run the script from the repository root:

```         
source("analysis/noise_eda.R")
```

Alternatively, from a terminal:

```         
Rscript analysis/noise_eda.R
```

The script reads the raw CSV and generates:

-   processed summary tables in `data/processed/`;

-   figures in `figures/`; and

-   a cached local R object in `data/processed/noise_eda_results.rds`.

The RDS file is generated automatically and does not need to be committed to GitHub.

The Quarto analysis document is:

```         
noise_eda.qmd
```

## Data-quality workflow

The analysis performs the following checks before interpreting the data:

1.  verifies row and column counts;

2.  identifies relevant noise, time, sensor and coordinate variables;

3.  checks missing values;

4.  checks exact duplicate rows;

5.  summarises the noise distribution;

6.  flags zero and extreme observations without deleting them;

7.  checks the actual observation frequency;

8.  compares sensor-specific coverage periods;

9.  identifies which sensors are active over time; and

10. assesses whether changing sensor composition affects pooled results.

## Robustness checks

The analysis includes three important robustness checks.

### Changing sensor composition

The number and identity of active sensors change over time. Missing calendar dates are inserted before plotting the pooled daily series so that observations are not connected across data gaps.

The large apparent early increase in the original plot was partly caused by a line drawn across a 158-day period with no valid noise observations.

### Balanced-sensor analysis

A balanced sensitivity analysis uses the same three sensors:

-   `ICTMicroclimate-01`;

-   `ICTMicroclimate-02`; and

-   `ICTMicroclimate-03`.

The common analysis period is:

```         
2023-01-01 to 2026-06-30
```

Weekly medians are first calculated within each sensor and then combined using an equal-sensor median.

### Sensor-standardised summaries

The hourly and weekday sensitivity analyses:

1.  calculate a median for each sensor × hour or sensor × weekday;

2.  calculate the median across sensors.

This prevents sensors with more observations from receiving greater weight.

## Preliminary descriptive findings

The current analysis indicates that:

-   recorded noise is generally lower overnight and higher during the daytime and afternoon;

-   the sensor-standardised hourly median is lowest around 03:00 and highest around 15:00–16:00;

-   differences between weekdays are relatively small;

-   Friday has the highest typical weekday value and Sunday the lowest;

-   sensor-level medians differ substantially across monitored locations;

-   sensor coverage changes materially over time;

-   one device, `aws5-0999`, contains no valid noise observations; and

-   the monitored locations cannot be treated as representative of all Melbourne locations.

These findings are descriptive and should not be interpreted causally.
