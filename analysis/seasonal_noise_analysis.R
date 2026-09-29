options(stringsAsFactors = FALSE, scipen = 999)

raw_path <- file.path("data", "raw", "microclimate_sensors.csv")
summary_path <- file.path("data", "processed", "seasonal_noise_summary.csv")
coverage_path <- file.path("data", "processed", "sensor_season_coverage.csv")
report_path <- file.path("analysis", "seasonal_noise_analysis.md")
boxplot_path <- file.path("figures", "fig15_seasonal_noise_boxplot.png")
heatmap_path <- file.path("figures", "fig16_sensor_season_heatmap.png")

PRIMARY_COVERAGE_THRESHOLD <- 0.75
ALTERNATIVE_COVERAGE_THRESHOLD <- 0.50
MAIN_SEASON_YEARS <- 2023:2025
MELBOURNE_TZ <- "Australia/Melbourne"
SEASON_LEVELS <- c("Summer", "Autumn", "Winter", "Spring")

if (!file.exists(raw_path)) {
  stop("Missing required input: ", raw_path, call. = FALSE)
}
dir.create(dirname(summary_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(boxplot_path), recursive = TRUE, showWarnings = FALSE)

message("Reading Device_id, Time and Noise from the raw sensor snapshot...")
noise <- read.csv(
  raw_path,
  check.names = FALSE,
  na.strings = c("", "NA", "null"),
  colClasses = c("character", "character", rep("NULL", 13), "numeric")
)
names(noise)[1] <- sub("^\\ufeff|^\\xef\\xbb\\xbf", "", names(noise)[1])
required_fields <- c("Device_id", "Time", "Noise")
missing_fields <- setdiff(required_fields, names(noise))
if (length(missing_fields)) {
  stop("Raw input is missing fields: ", paste(missing_fields, collapse = ", "), call. = FALSE)
}

time_normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", noise$Time)
noise$timestamp <- as.POSIXct(time_normalized, format = "%Y-%m-%dT%H:%M:%S%z", tz = MELBOURNE_TZ)
if (anyNA(noise$timestamp)) stop("Raw input contains unparseable timestamps.", call. = FALSE)
noise$Noise <- suppressWarnings(as.numeric(noise$Noise))
noise$date <- as.Date(noise$timestamp, tz = MELBOURNE_TZ)
noise$calendar_year <- as.integer(format(noise$timestamp, "%Y", tz = MELBOURNE_TZ))
noise$month <- as.integer(format(noise$timestamp, "%m", tz = MELBOURNE_TZ))
noise$season <- ifelse(
  noise$month %in% c(12L, 1L, 2L), "Summer",
  ifelse(noise$month %in% 3:5, "Autumn", ifelse(noise$month %in% 6:8, "Winter", "Spring"))
)
noise$season <- factor(noise$season, levels = SEASON_LEVELS, ordered = TRUE)
noise$season_year <- noise$calendar_year + ifelse(noise$month == 12L, 1L, 0L)
noise$valid_noise <- is.finite(noise$Noise)

if (!all(noise$season[noise$month == 12L] == "Summer") ||
    !all(noise$season_year[noise$month == 12L] == noise$calendar_year[noise$month == 12L] + 1L)) {
  stop("December season-year assignment failed.", call. = FALSE)
}

month_coverage <- aggregate(
  month ~ calendar_year,
  unique(noise[c("calendar_year", "month")]),
  function(x) paste(sort(unique(x)), collapse = ",")
)
month_counts <- aggregate(month ~ calendar_year, unique(noise[c("calendar_year", "month")]), length)
names(month_counts)[2] <- "n_months"
month_coverage <- merge(month_coverage, month_counts, by = "calendar_year", sort = TRUE)
complete_calendar_years <- month_coverage$calendar_year[month_coverage$n_months == 12L]
incomplete_calendar_years <- month_coverage$calendar_year[month_coverage$n_months < 12L]
if (!identical(as.integer(complete_calendar_years), 2023:2025)) {
  stop("Unexpected complete-calendar-year set: ", paste(complete_calendar_years, collapse = ", "), call. = FALSE)
}

season_period <- function(season_year, season) {
  if (season == "Summer") {
    start <- as.Date(sprintf("%d-12-01", season_year - 1L))
    end <- as.Date(sprintf("%d-03-01", season_year)) - 1L
  } else if (season == "Autumn") {
    start <- as.Date(sprintf("%d-03-01", season_year))
    end <- as.Date(sprintf("%d-06-01", season_year)) - 1L
  } else if (season == "Winter") {
    start <- as.Date(sprintf("%d-06-01", season_year))
    end <- as.Date(sprintf("%d-09-01", season_year)) - 1L
  } else {
    start <- as.Date(sprintf("%d-09-01", season_year))
    end <- as.Date(sprintf("%d-12-01", season_year)) - 1L
  }
  data.frame(
    season_year = season_year,
    season = season,
    period_start = start,
    period_end = end,
    expected_days = as.integer(end - start) + 1L,
    expected_records = (as.integer(end - start) + 1L) * 96L,
    stringsAsFactors = FALSE
  )
}

periods <- do.call(rbind, lapply(MAIN_SEASON_YEARS, function(year) {
  do.call(rbind, lapply(SEASON_LEVELS, function(season) season_period(year, season)))
}))
periods$season <- factor(periods$season, levels = SEASON_LEVELS, ordered = TRUE)

device_ids <- sort(unique(noise$Device_id))
coverage_rows <- vector("list", length(device_ids) * nrow(periods))
row_index <- 0L
for (device_id in device_ids) {
  for (i in seq_len(nrow(periods))) {
    row_index <- row_index + 1L
    period <- periods[i, ]
    selected <- noise$Device_id == device_id &
      noise$season_year == period$season_year & noise$season == period$season
    valid_selected <- selected & noise$valid_noise
    valid_dates <- unique(noise$date[valid_selected])
    valid_times <- unique(noise$timestamp[valid_selected])
    coverage_rows[[row_index]] <- data.frame(
      coverage_scope = "season_year",
      device_id = device_id,
      season_year = period$season_year,
      season = as.character(period$season),
      period_start = format(period$period_start, "%Y-%m-%d"),
      period_end = format(period$period_end, "%Y-%m-%d"),
      n_observations = sum(selected),
      n_valid_noise = sum(valid_selected),
      n_nonzero_noise = sum(valid_selected & noise$Noise != 0),
      n_zero_noise = sum(valid_selected & noise$Noise == 0),
      distinct_dates = length(unique(noise$date[selected])),
      active_days = length(valid_dates),
      first_timestamp = if (length(valid_times)) format(min(valid_times), "%Y-%m-%dT%H:%M:%S%z", tz = MELBOURNE_TZ) else NA_character_,
      last_timestamp = if (length(valid_times)) format(max(valid_times), "%Y-%m-%dT%H:%M:%S%z", tz = MELBOURNE_TZ) else NA_character_,
      n_unique_valid_timestamps = length(valid_times),
      expected_days = period$expected_days,
      expected_records = period$expected_records,
      active_day_coverage_rate = length(valid_dates) / period$expected_days,
      record_coverage_rate = min(length(valid_times) / period$expected_records, 1),
      complete_calendar_year_scope = TRUE,
      partial_year_flag = FALSE,
      stringsAsFactors = FALSE
    )
  }
}
coverage_year <- do.call(rbind, coverage_rows)

pooled_coverage <- do.call(rbind, lapply(device_ids, function(device_id) {
  do.call(rbind, lapply(SEASON_LEVELS, function(season) {
    z <- coverage_year[coverage_year$device_id == device_id & coverage_year$season == season, ]
    data.frame(
      coverage_scope = "pooled_complete_season_years",
      device_id = device_id,
      season_year = NA_integer_,
      season = season,
      period_start = min(z$period_start),
      period_end = max(z$period_end),
      n_observations = sum(z$n_observations),
      n_valid_noise = sum(z$n_valid_noise),
      n_nonzero_noise = sum(z$n_nonzero_noise),
      n_zero_noise = sum(z$n_zero_noise),
      distinct_dates = sum(z$distinct_dates),
      active_days = sum(z$active_days),
      first_timestamp = if (all(is.na(z$first_timestamp))) NA_character_ else min(z$first_timestamp, na.rm = TRUE),
      last_timestamp = if (all(is.na(z$last_timestamp))) NA_character_ else max(z$last_timestamp, na.rm = TRUE),
      n_unique_valid_timestamps = sum(z$n_unique_valid_timestamps),
      expected_days = sum(z$expected_days),
      expected_records = sum(z$expected_records),
      active_day_coverage_rate = sum(z$active_days) / sum(z$expected_days),
      record_coverage_rate = min(sum(z$n_unique_valid_timestamps) / sum(z$expected_records), 1),
      complete_calendar_year_scope = TRUE,
      partial_year_flag = FALSE,
      stringsAsFactors = FALSE
    )
  }))
}))

coverage <- rbind(coverage_year, pooled_coverage)
coverage$season <- factor(coverage$season, levels = SEASON_LEVELS, ordered = TRUE)
coverage$qualifies_primary_threshold <- coverage$active_day_coverage_rate >= PRIMARY_COVERAGE_THRESHOLD
coverage$qualifies_alternative_threshold <- coverage$active_day_coverage_rate >= ALTERNATIVE_COVERAGE_THRESHOLD
coverage$season_definition <- "Summer Dec-Feb; Autumn Mar-May; Winter Jun-Aug; Spring Sep-Nov"
coverage$season_year_rule <- "December belongs to the following season_year"
coverage$generation_script <- "analysis/seasonal_noise_analysis.R"
coverage <- coverage[order(coverage$coverage_scope, coverage$device_id, coverage$season_year, coverage$season), ]
rownames(coverage) <- NULL

coverage_key <- paste(coverage$coverage_scope, coverage$device_id, ifelse(is.na(coverage$season_year), "", coverage$season_year), coverage$season, sep = "|")
if (anyDuplicated(coverage_key)) stop("Duplicate coverage keys were generated.", call. = FALSE)
write.csv(coverage, coverage_path, row.names = FALSE, na = "")

pooled <- coverage[coverage$coverage_scope == "pooled_complete_season_years", ]
eligible_sensors <- function(threshold) {
  by_sensor <- split(pooled, pooled$device_id)
  sort(names(Filter(function(z) nrow(z) == 4L && all(z$active_day_coverage_rate >= threshold), by_sensor)))
}
balanced_primary <- eligible_sensors(PRIMARY_COVERAGE_THRESHOLD)
balanced_alternative <- eligible_sensors(ALTERNATIVE_COVERAGE_THRESHOLD)
if (!length(balanced_primary)) stop("No sensors qualify for the primary balanced analysis.", call. = FALSE)

main <- noise[noise$season_year %in% MAIN_SEASON_YEARS & noise$valid_noise, ]

build_units <- function(data, zero_rule) {
  z <- data
  if (zero_rule == "zeros_excluded") z <- z[z$Noise != 0, ]
  if (!nrow(z)) return(data.frame())
  sensor_date <- aggregate(Noise ~ Device_id + date + season_year + season, z, median)
  names(sensor_date)[5] <- "sensor_date_median"
  sensor_season_year <- aggregate(sensor_date_median ~ Device_id + season_year + season, sensor_date, median)
  names(sensor_season_year)[4] <- "analysis_value"
  list(records = z, sensor_date = sensor_date, sensor_season_year = sensor_season_year)
}

summarise_season <- function(analysis_sample, zero_rule, threshold_label, threshold, sensors, aggregation_level) {
  units <- build_units(main[main$Device_id %in% sensors, ], zero_rule)
  do.call(rbind, lapply(SEASON_LEVELS, function(season) {
    record_part <- units$records[units$records$season == season, ]
    date_part <- units$sensor_date[units$sensor_date$season == season, ]
    season_part <- units$sensor_season_year[units$sensor_season_year$season == season, ]
    values <- if (aggregation_level == "sensor_season_year_medians") season_part$analysis_value else record_part$Noise
    values <- values[is.finite(values)]
    available <- sort(unique(record_part$Device_id))
    q <- if (length(values)) quantile(values, c(0.25, 0.75), names = FALSE) else c(NA_real_, NA_real_)
    data.frame(
      analysis_sample = analysis_sample,
      zero_rule = zero_rule,
      season = season,
      aggregation_level = aggregation_level,
      median_noise = if (length(values)) median(values) else NA_real_,
      q1 = q[1],
      q3 = q[2],
      iqr = q[2] - q[1],
      n_observations = nrow(record_part),
      n_analysis_units = length(values),
      n_sensor_days = nrow(date_part),
      n_days = length(unique(record_part$date)),
      n_sensors = length(available),
      available_sensors = paste(available, collapse = ";"),
      coverage_threshold = threshold,
      coverage_threshold_label = threshold_label,
      year_scope = "complete season-years 2023-2025 (December assigned to following season-year)",
      partial_year_flag = FALSE,
      stringsAsFactors = FALSE
    )
  }))
}

summary_parts <- list()
all_sensors <- sort(unique(main$Device_id[main$valid_noise]))
for (aggregation_level in c("sensor_season_year_medians", "raw_records_descriptive")) {
  for (zero_rule in c("zeros_retained", "zeros_excluded")) {
    summary_parts[[length(summary_parts) + 1L]] <- summarise_season(
      "all_available", zero_rule, "not applicable", NA_real_, all_sensors, aggregation_level
    )
    summary_parts[[length(summary_parts) + 1L]] <- summarise_season(
      "balanced", zero_rule, "primary 75% active-day coverage in every pooled season", PRIMARY_COVERAGE_THRESHOLD,
      balanced_primary, aggregation_level
    )
    summary_parts[[length(summary_parts) + 1L]] <- summarise_season(
      "balanced", zero_rule, "alternative 50% active-day coverage in every pooled season", ALTERNATIVE_COVERAGE_THRESHOLD,
      balanced_alternative, aggregation_level
    )
  }
}
seasonal_summary <- do.call(rbind, summary_parts)
seasonal_summary$season <- factor(seasonal_summary$season, levels = SEASON_LEVELS, ordered = TRUE)

primary_rows <- seasonal_summary[
  seasonal_summary$analysis_sample == "all_available" &
    seasonal_summary$zero_rule == "zeros_retained" &
    seasonal_summary$aggregation_level == "sensor_season_year_medians",
]
primary_median <- setNames(primary_rows$median_noise, as.character(primary_rows$season))
primary_rank <- setNames(rank(-primary_rows$median_noise, ties.method = "min"), as.character(primary_rows$season))
seasonal_summary$difference_from_primary <- seasonal_summary$median_noise - primary_median[as.character(seasonal_summary$season)]
seasonal_summary$season_rank <- ave(-seasonal_summary$median_noise,
  interaction(
    seasonal_summary$analysis_sample, seasonal_summary$zero_rule,
    seasonal_summary$coverage_threshold_label, seasonal_summary$aggregation_level,
    drop = TRUE
  ),
  FUN = function(x) rank(x, ties.method = "min")
)
seasonal_summary$ranking_changed_from_primary <- seasonal_summary$season_rank != primary_rank[as.character(seasonal_summary$season)]
seasonal_summary$season_definition <- "Summer Dec-Feb; Autumn Mar-May; Winter Jun-Aug; Spring Sep-Nov"
seasonal_summary$generation_script <- "analysis/seasonal_noise_analysis.R"
seasonal_summary <- seasonal_summary[order(
  seasonal_summary$aggregation_level, seasonal_summary$analysis_sample,
  seasonal_summary$coverage_threshold_label, seasonal_summary$zero_rule, seasonal_summary$season
), ]
rownames(seasonal_summary) <- NULL

summary_key_fields <- c("analysis_sample", "zero_rule", "season", "aggregation_level", "coverage_threshold_label", "year_scope")
summary_key <- do.call(paste, c(lapply(seasonal_summary[summary_key_fields], as.character), sep = "|"))
if (anyDuplicated(summary_key)) stop("Duplicate seasonal summary keys were generated.", call. = FALSE)
if (!identical(unique(as.character(seasonal_summary$season)), SEASON_LEVELS)) stop("Season order validation failed.", call. = FALSE)
write.csv(seasonal_summary, summary_path, row.names = FALSE, na = "")

# Figure 1 uses sensor-season-year medians so raw record volume does not determine the distribution.
box_units <- build_units(main[main$Device_id %in% balanced_primary, ], "zeros_retained")$sensor_season_year
box_units$season <- factor(box_units$season, levels = SEASON_LEVELS, ordered = TRUE)
png(boxplot_path, width = 1800, height = 1100, res = 180)
par(mar = c(6.5, 5.5, 3.5, 1.5), las = 1)
boxplot(
  analysis_value ~ season,
  data = box_units,
  levels = SEASON_LEVELS,
  col = c("#F4A261", "#D99B5B", "#6BAED6", "#79B473"),
  border = "#374151",
  ylab = "Median recorded Noise value (dataset units)",
  xlab = "Australian meteorological season",
  main = "Seasonal recorded Noise values in the balanced sensor sample",
  outline = TRUE
)
grid(nx = NA, ny = NULL, col = "#E5E7EB")
boxplot(analysis_value ~ season, data = box_units, levels = SEASON_LEVELS, add = TRUE, axes = FALSE,
        col = adjustcolor(c("#F4A261", "#D99B5B", "#6BAED6", "#79B473"), 0.72), border = "#374151")
mtext(
  paste0(
    "Sensor-season-year medians; season-years 2023-2025; zeros retained; balanced sensors require >=75% active-day coverage in every season (",
    paste(balanced_primary, collapse = ", "), ")"
  ),
  side = 1, line = 4.5, cex = 0.66, col = "#555555"
)
dev.off()

# Figure 2 leaves ineligible cells blank and marks them with X; missing does not become zero.
heat <- pooled
heat$median_noise <- NA_real_
for (i in seq_len(nrow(heat))) {
  selected <- main$Device_id == heat$device_id[i] & main$season == heat$season[i]
  unit <- if (any(selected)) aggregate(Noise ~ season_year, main[selected, ], median) else data.frame()
  if (heat$qualifies_primary_threshold[i] && nrow(unit)) heat$median_noise[i] <- median(unit$Noise)
}
heat_matrix <- matrix(NA_real_, nrow = length(device_ids), ncol = length(SEASON_LEVELS), dimnames = list(device_ids, SEASON_LEVELS))
for (i in seq_len(nrow(heat))) heat_matrix[heat$device_id[i], as.character(heat$season[i])] <- heat$median_noise[i]
finite_heat <- heat_matrix[is.finite(heat_matrix)]
heat_limits <- range(finite_heat)
palette <- hcl.colors(100, "YlOrRd", rev = FALSE)
png(heatmap_path, width = 1900, height = 1350, res = 180)
par(mar = c(7, 11, 4, 5), las = 1)
plot(NA, xlim = c(0.5, 4.5), ylim = c(0.5, length(device_ids) + 0.5), xaxs = "i", yaxs = "i",
     xaxt = "n", yaxt = "n", xlab = "", ylab = "", main = "Recorded Noise values by sensor and season")
for (x in 1:4) for (y in seq_along(device_ids)) rect(x - 0.5, y - 0.5, x + 0.5, y + 0.5, col = "#F3F4F6", border = "white")
image(1:4, seq_along(device_ids), t(heat_matrix), add = TRUE, col = palette, zlim = heat_limits, axes = FALSE)
eligible_cells <- which(is.finite(heat_matrix), arr.ind = TRUE)
if (nrow(eligible_cells)) {
  eligible_values <- heat_matrix[eligible_cells]
  eligible_text_col <- ifelse(eligible_values < mean(heat_limits), "white", "#1F2937")
  text(eligible_cells[, 2], eligible_cells[, 1], labels = sprintf("%.1f", eligible_values),
       col = eligible_text_col, cex = 0.72, font = 2)
}
axis(1, at = 1:4, labels = SEASON_LEVELS, las = 1)
axis(2, at = seq_along(device_ids), labels = device_ids, las = 1, cex.axis = 0.75)
missing_cells <- which(!is.finite(heat_matrix), arr.ind = TRUE)
if (nrow(missing_cells)) text(missing_cells[, 2], missing_cells[, 1], labels = "X", col = "#6B7280", cex = 0.9)
box()
mtext("Australian meteorological season", side = 1, line = 3)
mtext("Sensor", side = 2, line = 7.5)
mtext(
  "Cell value: median of season-year medians, zeros retained. X: below 75% pooled active-day coverage or no eligible data. Season-years 2023-2025.",
  side = 1, line = 5.2, cex = 0.68, col = "#555555"
)
legend("topright", legend = sprintf("Eligible range: %.1f to %.1f", heat_limits[1], heat_limits[2]), bty = "n", cex = 0.8)
dev.off()

fmt <- function(x, digits = 2L) ifelse(is.finite(x), format(round(x, digits), nsmall = digits, trim = TRUE), "NA")
primary_rows <- seasonal_summary[
  seasonal_summary$analysis_sample == "all_available" &
    seasonal_summary$zero_rule == "zeros_retained" &
    seasonal_summary$aggregation_level == "sensor_season_year_medians",
]
primary <- primary_rows[order(primary_rows$season_rank), ]
balanced <- seasonal_summary[
  seasonal_summary$analysis_sample == "balanced" &
    seasonal_summary$zero_rule == "zeros_retained" &
    seasonal_summary$aggregation_level == "sensor_season_year_medians" &
    seasonal_summary$coverage_threshold == PRIMARY_COVERAGE_THRESHOLD,
]
zero_excluded <- seasonal_summary[
  seasonal_summary$analysis_sample == "all_available" &
    seasonal_summary$zero_rule == "zeros_excluded" &
    seasonal_summary$aggregation_level == "sensor_season_year_medians",
]
alternative <- seasonal_summary[
  seasonal_summary$analysis_sample == "balanced" &
    seasonal_summary$zero_rule == "zeros_retained" &
    seasonal_summary$aggregation_level == "sensor_season_year_medians" &
    seasonal_summary$coverage_threshold == ALTERNATIVE_COVERAGE_THRESHOLD,
]
primary_by_season <- primary_rows[match(SEASON_LEVELS, primary_rows$season), ]
balanced_by_season <- balanced[match(SEASON_LEVELS, balanced$season), ]
alternative_by_season <- alternative[match(SEASON_LEVELS, alternative$season), ]
zero_by_season <- zero_excluded[match(SEASON_LEVELS, zero_excluded$season), ]

season_table <- c(
  "| Season | All available median | IQR | 75% balanced median | 50% balanced median | Zero-excluded median |",
  "|---|---:|---:|---:|---:|---:|",
  vapply(seq_along(SEASON_LEVELS), function(i) paste0(
    "| ", SEASON_LEVELS[i], " | ", fmt(primary_by_season$median_noise[i]), " | ", fmt(primary_by_season$iqr[i]),
    " | ", fmt(balanced_by_season$median_noise[i]), " | ", fmt(alternative_by_season$median_noise[i]),
    " | ", fmt(zero_by_season$median_noise[i]), " |"
  ), character(1))
)
highest <- primary[1, ]
lowest <- primary[nrow(primary), ]
all_balanced_max_difference <- max(abs(balanced_by_season$median_noise - primary_by_season$median_noise))
zero_max_difference <- max(abs(zero_by_season$median_noise - primary_by_season$median_noise))
season_order <- function(x) paste(as.character(x$season[order(x$season_rank)]), collapse = " > ")
primary_order <- season_order(primary_by_season)
balanced_order <- season_order(balanced_by_season)
alternative_order <- season_order(alternative_by_season)

report <- c(
  "# Seasonal Recorded Noise Analysis",
  "",
  "## Scope",
  "",
  "This analysis completes the seasonal component of RQ1: How do recorded Noise values vary by time of day, day of week and season? Hour-of-day and weekday analyses are unchanged.",
  "",
  "The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.",
  "",
  "## Season and year definitions",
  "",
  "Australian meteorological seasons are Summer (December-February), Autumn (March-May), Winter (June-August) and Spring (September-November), in that order. December is assigned to the following `season_year`, so Summer 2024 consists of December 2023 through February 2024.",
  "",
  paste0("The raw snapshot covers ", min(noise$date), " to ", max(noise$date), ". Complete calendar years are ", paste(complete_calendar_years, collapse = ", "), ". Incomplete calendar years are ", paste(incomplete_calendar_years, collapse = ", "), ". The main comparison uses complete season-years 2023-2025, spanning December 2022 through November 2025. Data from 2026 remain partial-year descriptive context and are not included in the four-season comparison."),
  "",
  "## Coverage rule and aggregation",
  "",
  paste0("The primary balanced rule requires each sensor to have valid Noise observations on at least ", PRIMARY_COVERAGE_THRESHOLD * 100, "% of expected calendar days in every pooled season across season-years 2023-2025. Active-day coverage was chosen because the source is approximately 15-minute data but outages, duplicate timestamps and daylight-saving transitions make strict record-count coverage less suitable for seasonal eligibility. The threshold is fixed at the top of the script and was not selected from the seasonal results."),
  "",
  paste0("The alternative threshold is ", ALTERNATIVE_COVERAGE_THRESHOLD * 100, "%. Sensors retained at 75%: `", paste(balanced_primary, collapse = "`, `"), "`. Sensors retained at 50%: `", paste(balanced_alternative, collapse = "`, `"), "`."),
  "",
  "The primary evidence uses a hierarchy of raw records to sensor-date medians and then sensor-season-year medians. Seasonal summaries compare these final units so sensors with more raw records do not automatically receive more weight. Raw-record summaries remain in the CSV as descriptive information only.",
  "",
  "## Main results",
  "",
  season_table,
  "",
  paste0(highest$season, " has the highest all-available median (", fmt(highest$median_noise), "), while ", lowest$season, " has the lowest (", fmt(lowest$median_noise), "). The difference is ", fmt(highest$median_noise - lowest$median_noise), " dataset units among the eligible monitored locations."),
  "",
  paste0("The maximum absolute difference between the all-available and 75% balanced seasonal medians is ", fmt(all_balanced_max_difference), " dataset units. The maximum difference after excluding zero values is ", fmt(zero_max_difference), " dataset units."),
  "",
  "## Composition and sensitivity",
  "",
  paste0("The all-available analysis includes up to ", max(primary_by_season$n_sensors), " sensors, while the primary balanced analysis includes ", length(balanced_primary), ". Differences between these summaries show the contribution of changing sensor availability and unequal temporal coverage. The 50% alternative threshold is retained in the CSV so the coverage choice can be assessed without changing the pre-specified primary rule."),
  "",
  paste0("The all-available seasonal order is ", primary_order, "; the 75% balanced order is ", balanced_order, "; and the 50% balanced order is ", alternative_order, ". The 75% ranking is therefore not identical to the all-available ranking, although Summer remains lowest in all three summaries. The identity of the highest season is sensitive to the coverage threshold and sensor composition."),
  "",
  paste0("The all-available zero-excluded seasonal ranking is ", if (identical(order(primary_by_season$season_rank), order(zero_by_season$season_rank))) "unchanged" else "not identical", ". Zero exclusion is a sensitivity analysis only and does not establish that zero readings are faults."),
  "",
  "## Interpretation",
  "",
  "The reported differences describe the monitored locations represented in each eligible seasonal sample. They do not demonstrate a causal effect of weather, tourism, venue activity or any other seasonal mechanism. They also should not be interpreted as a city-wide seasonal pattern.",
  "",
  "Figure 15 shows the balanced sensor-season-year distribution. Figure 16 shows sensor-specific seasonal medians and marks cells below the primary coverage threshold with X rather than replacing missing or ineligible values with zero.",
  "",
  "## Outputs",
  "",
  "- `data/processed/seasonal_noise_summary.csv`",
  "- `data/processed/sensor_season_coverage.csv`",
  "- `figures/fig15_seasonal_noise_boxplot.png`",
  "- `figures/fig16_sensor_season_heatmap.png`"
)
writeLines(report, report_path, useBytes = TRUE)

message("Created ", summary_path, " with ", nrow(seasonal_summary), " unique rows.")
message("Created ", coverage_path, " with ", nrow(coverage), " unique rows.")
message("Primary balanced sensors: ", paste(balanced_primary, collapse = ", "))
message("Alternative balanced sensors: ", paste(balanced_alternative, collapse = ", "))
message("Created ", boxplot_path, " and ", heatmap_path, ".")
message("Created ", report_path, ".")
