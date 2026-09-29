options(stringsAsFactors = FALSE, scipen = 999)

raw_path <- file.path("data", "raw", "microclimate_sensors.csv")
integrated_path <- file.path("data", "processed", "noise_pedestrian_integrated_2025.csv")
output_path <- file.path("data", "processed", "noise_zero_value_sensitivity.csv")
report_path <- file.path("analysis", "noise_zero_value_sensitivity.md")

required_files <- c(raw_path, integrated_path)
missing_files <- required_files[!file.exists(required_files)]
if (length(missing_files)) {
  stop("Missing required input files: ", paste(missing_files, collapse = ", "), call. = FALSE)
}

message("Reading Device_id, Time and Noise from the raw sensor snapshot...")
noise <- read.csv(
  raw_path,
  check.names = FALSE,
  na.strings = c("", "NA", "null"),
  colClasses = c("character", "character", rep("NULL", 13), "numeric")
)
names(noise)[1] <- sub("^\\ufeff|^\\xef\\xbb\\xbf", "", names(noise)[1])
required_noise_fields <- c("Device_id", "Time", "Noise")
missing_noise_fields <- setdiff(required_noise_fields, names(noise))
if (length(missing_noise_fields)) {
  stop("Raw noise input is missing fields: ", paste(missing_noise_fields, collapse = ", "), call. = FALSE)
}

time_normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", noise$Time)
noise$timestamp <- as.POSIXct(
  time_normalized,
  format = "%Y-%m-%dT%H:%M:%S%z",
  tz = "Australia/Melbourne"
)
if (anyNA(noise$timestamp)) {
  stop("Raw noise input contains unparseable timestamps.", call. = FALSE)
}
noise$Noise <- suppressWarnings(as.numeric(noise$Noise))
noise$local_hour <- as.integer(format(noise$timestamp, "%H", tz = "Australia/Melbourne"))
noise$weekday_number <- as.integer(format(noise$timestamp, "%u", tz = "Australia/Melbourne"))
noise$year <- as.integer(format(noise$timestamp, "%Y", tz = "Australia/Melbourne"))
noise$time_period <- ifelse(noise$local_hour >= 18L | noise$local_hour < 6L, "Night-time 18:00-05:59", "Daytime 06:00-17:59")

valid <- is.finite(noise$Noise)
primary <- valid
sensitivity <- valid & noise$Noise != 0

make_row <- function(
    analysis_section, group_type, group_value, metric,
    primary_estimate = NA_real_, sensitivity_estimate = NA_real_,
    primary_n = NA_integer_, sensitivity_n = NA_integer_,
    buffer_m = NA_integer_, model = NA_character_, term = NA_character_,
    zero_count = NA_integer_, zero_percent = NA_real_,
    primary_rank = NA_integer_, sensitivity_rank = NA_integer_) {
  absolute_difference <- if (is.finite(primary_estimate) && is.finite(sensitivity_estimate)) {
    abs(sensitivity_estimate - primary_estimate)
  } else {
    NA_real_
  }
  relative_difference_percent <- if (
      is.finite(primary_estimate) && primary_estimate != 0 && is.finite(sensitivity_estimate)) {
    100 * absolute_difference / abs(primary_estimate)
  } else {
    NA_real_
  }
  data.frame(
    analysis_section = analysis_section,
    group_type = group_type,
    group_value = as.character(group_value),
    metric = metric,
    buffer_m = buffer_m,
    model = model,
    term = term,
    primary_estimate = primary_estimate,
    sensitivity_estimate = sensitivity_estimate,
    absolute_difference = absolute_difference,
    relative_difference_percent = relative_difference_percent,
    primary_n = as.integer(primary_n),
    sensitivity_n = as.integer(sensitivity_n),
    zero_count = as.integer(zero_count),
    zero_percent = zero_percent,
    primary_rank = as.integer(primary_rank),
    sensitivity_rank = as.integer(sensitivity_rank),
    stringsAsFactors = FALSE
  )
}

rows <- list()
add_row <- function(...) rows[[length(rows) + 1L]] <<- make_row(...)

add_zero_distribution <- function(group_type, groups) {
  for (group_value in groups) {
    selected <- switch(
      group_type,
      total = rep(TRUE, nrow(noise)),
      sensor = noise$Device_id == group_value,
      year = noise$year == as.integer(group_value),
      hour = noise$local_hour == as.integer(group_value),
      time_period = noise$time_period == group_value
    )
    denominator <- sum(valid & selected)
    zeros <- sum(valid & selected & noise$Noise == 0)
    add_row(
      "zero_distribution", group_type, group_value, "Noise == 0 distribution",
      primary_n = denominator, sensitivity_n = denominator - zeros,
      zero_count = zeros,
      zero_percent = if (denominator > 0) 100 * zeros / denominator else NA_real_
    )
  }
}

add_zero_distribution("total", "all valid Noise observations")
add_zero_distribution("sensor", sort(unique(noise$Device_id)))
add_zero_distribution("year", sort(unique(noise$year)))
add_zero_distribution("hour", 0:23)
add_zero_distribution("time_period", c("Daytime 06:00-17:59", "Night-time 18:00-05:59"))

median_comparison <- function(
    selected, group_type, group_value,
    metric = "median recorded Noise value (dataset units)") {
  p <- noise$Noise[selected & primary]
  s <- noise$Noise[selected & sensitivity]
  add_row(
    "descriptive_median", group_type, group_value, metric,
    primary_estimate = if (length(p)) median(p) else NA_real_,
    sensitivity_estimate = if (length(s)) median(s) else NA_real_,
    primary_n = length(p), sensitivity_n = length(s)
  )
}

for (hour in 0:23) median_comparison(noise$local_hour == hour, "hour", sprintf("%02d:00", hour))
weekday_names <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
for (day in 1:7) median_comparison(noise$weekday_number == day, "weekday", weekday_names[day])

sensor_start <- length(rows) + 1L
for (device_id in sort(unique(noise$Device_id))) {
  median_comparison(noise$Device_id == device_id, "sensor", device_id)
}
sensor_end <- length(rows)
sensor_estimates <- do.call(rbind, rows[sensor_start:sensor_end])
sensor_estimates$primary_rank <- rank(-sensor_estimates$primary_estimate, ties.method = "min", na.last = "keep")
sensor_estimates$sensitivity_rank <- rank(-sensor_estimates$sensitivity_estimate, ties.method = "min", na.last = "keep")
rows[sensor_start:sensor_end] <- lapply(seq_len(nrow(sensor_estimates)), function(i) sensor_estimates[i, , drop = FALSE])

night_2025 <- noise$year == 2025L & (noise$local_hour >= 18L | noise$local_hour < 6L)
median_comparison(night_2025, "analysis_period", "2025 night-time 18:00-05:59", "2025 night-time median recorded Noise value (dataset units)")

sensor_ids <- sort(unique(noise$Device_id))
sensor_night <- do.call(rbind, lapply(sensor_ids, function(device_id) {
  selected <- noise$Device_id == device_id & night_2025
  p <- noise$Noise[selected & primary]
  s <- noise$Noise[selected & sensitivity]
  data.frame(
    device_id = device_id,
    primary_outcome = if (length(p)) median(p) else NA_real_,
    sensitivity_outcome = if (length(s)) median(s) else NA_real_,
    primary_outcome_n = length(p),
    sensitivity_outcome_n = length(s),
    stringsAsFactors = FALSE
  )
}))

integrated <- read.csv(integrated_path, check.names = FALSE)
required_integrated_fields <- c(
  "device_id", "buffer_m", "mean_nighttime_avg_hourly_pedestrian_count",
  "sum_sensor_means_nighttime_avg_hourly_pedestrian_count",
  "total_bar_capacity_2024_baseline"
)
missing_integrated_fields <- setdiff(required_integrated_fields, names(integrated))
if (length(missing_integrated_fields)) {
  stop("Integrated 2025 input is missing fields: ", paste(missing_integrated_fields, collapse = ", "), call. = FALSE)
}
if (anyDuplicated(integrated[c("device_id", "buffer_m")])) {
  stop("Integrated 2025 input contains duplicate device_id + buffer_m keys.", call. = FALSE)
}
association <- merge(integrated, sensor_night, by = "device_id", all.x = TRUE, sort = FALSE)
association <- association[association$buffer_m == 500L, ]

correlation_estimate <- function(outcome, predictor, method) {
  keep <- is.finite(outcome) & is.finite(predictor)
  c(estimate = if (sum(keep) >= 3L) cor(outcome[keep], predictor[keep], method = method) else NA_real_, n = sum(keep))
}

add_correlation <- function(metric, predictor_name, predictor) {
  for (method in c("pearson", "spearman")) {
    p <- correlation_estimate(association$primary_outcome, predictor, method)
    s <- correlation_estimate(association$sensitivity_outcome, predictor, method)
    add_row(
      "urban_activity_association", "buffer", "500 m", paste(method, "correlation"),
      primary_estimate = p[["estimate"]], sensitivity_estimate = s[["estimate"]],
      primary_n = p[["n"]], sensitivity_n = s[["n"]], buffer_m = 500L,
      model = "bivariate correlation", term = predictor_name
    )
  }
}

pedestrian_mean <- association$mean_nighttime_avg_hourly_pedestrian_count
pedestrian_sum <- association$sum_sensor_means_nighttime_avg_hourly_pedestrian_count
bar_capacity <- association$total_bar_capacity_2024_baseline
add_correlation("correlation", "mean_nighttime_avg_hourly_pedestrian_count", pedestrian_mean)
add_correlation("correlation", "sum_sensor_means_nighttime_avg_hourly_pedestrian_count", pedestrian_sum)

fit_coefficient <- function(outcome, predictors, term) {
  model_data <- data.frame(y = outcome, predictors, check.names = FALSE)
  model_data <- model_data[complete.cases(model_data) & apply(model_data, 1, function(x) all(is.finite(x))), , drop = FALSE]
  if (nrow(model_data) <= ncol(predictors) + 1L) return(c(estimate = NA_real_, n = nrow(model_data)))
  fit <- lm(y ~ ., data = model_data)
  c(estimate = unname(coef(fit)[term]), n = nobs(fit))
}

add_model_term <- function(model_name, term_name, predictors, coefficient_name) {
  p <- fit_coefficient(association$primary_outcome, predictors, coefficient_name)
  s <- fit_coefficient(association$sensitivity_outcome, predictors, coefficient_name)
  add_row(
    "urban_activity_association", "buffer", "500 m", "OLS coefficient",
    primary_estimate = p[["estimate"]], sensitivity_estimate = s[["estimate"]],
    primary_n = p[["n"]], sensitivity_n = s[["n"]], buffer_m = 500L,
    model = model_name, term = term_name
  )
}

add_model_term(
  "simple_pedestrian_mean", "mean_nighttime_avg_hourly_pedestrian_count",
  data.frame(pedestrian_mean = pedestrian_mean), "pedestrian_mean"
)
add_model_term(
  "alternative_pedestrian_intensity", "sum_sensor_means_nighttime_avg_hourly_pedestrian_count",
  data.frame(pedestrian_sum = pedestrian_sum), "pedestrian_sum"
)
adjusted_predictors <- data.frame(pedestrian_mean = pedestrian_mean, bar_capacity = bar_capacity)
add_model_term(
  "exploratory_adjusted_2024_bar_capacity", "mean_nighttime_avg_hourly_pedestrian_count",
  adjusted_predictors, "pedestrian_mean"
)
add_model_term(
  "exploratory_adjusted_2024_bar_capacity", "total_bar_capacity_2024_baseline",
  adjusted_predictors, "bar_capacity"
)

result <- do.call(rbind, rows)
result$source_files <- paste(raw_path, integrated_path, sep = "; ")
result$primary_rule <- "Retain Noise == 0; exclude only missing/non-finite Noise"
result$sensitivity_rule <- "Exclude Noise == 0 and missing/non-finite Noise"
result$time_zone <- "Australia/Melbourne"
result$night_definition <- "18:00-05:59"
result$generation_script <- "analysis/noise_zero_value_sensitivity.R"

key_fields <- c("analysis_section", "group_type", "group_value", "metric", "buffer_m", "model", "term")
key <- do.call(paste, c(lapply(result[key_fields], function(x) ifelse(is.na(x), "", as.character(x))), sep = "|"))
if (anyDuplicated(key)) stop("Unexpected duplicate result keys were generated.", call. = FALSE)
if (sum(valid & noise$Noise == 0) != sum(result$zero_count[result$analysis_section == "zero_distribution" & result$group_type == "total"], na.rm = TRUE)) {
  stop("Zero-count reconciliation failed.", call. = FALSE)
}

write.csv(result, output_path, row.names = FALSE, na = "")

total_zero <- result[result$analysis_section == "zero_distribution" & result$group_type == "total", ]
night_result <- result[result$metric == "2025 night-time median recorded Noise value (dataset units)", ]
hour_results <- result[result$analysis_section == "descriptive_median" & result$group_type == "hour", ]
weekday_results <- result[result$analysis_section == "descriptive_median" & result$group_type == "weekday", ]
sensor_results <- result[result$analysis_section == "descriptive_median" & result$group_type == "sensor", ]
association_results <- result[result$analysis_section == "urban_activity_association", ]
top_zero_sensor <- result[result$analysis_section == "zero_distribution" & result$group_type == "sensor" & is.finite(result$zero_percent), ]
top_zero_sensor <- top_zero_sensor[order(-top_zero_sensor$zero_percent, -top_zero_sensor$zero_count), ][1, ]
top_zero_year <- result[result$analysis_section == "zero_distribution" & result$group_type == "year", ]
top_zero_year <- top_zero_year[order(-top_zero_year$zero_count), ][1, ]
top_zero_hour <- result[result$analysis_section == "zero_distribution" & result$group_type == "hour", ]
top_zero_hour <- top_zero_hour[order(-top_zero_hour$zero_count), ][1, ]
ranking_stable <- identical(
  sensor_results$group_value[order(sensor_results$primary_rank, na.last = NA)],
  sensor_results$group_value[order(sensor_results$sensitivity_rank, na.last = NA)]
)

fmt <- function(x, digits = 4L) ifelse(is.finite(x), format(round(x, digits), nsmall = digits, trim = TRUE), "NA")
association_lines <- vapply(seq_len(nrow(association_results)), function(i) {
  x <- association_results[i, ]
  paste0(
    "- ", x$metric, ", `", x$model, "`, `", x$term, "`: ",
    fmt(x$primary_estimate, 6), " (primary) versus ", fmt(x$sensitivity_estimate, 6),
    " (excluding zero), absolute difference ", fmt(x$absolute_difference, 6),
    ", n=", x$primary_n, "/", x$sensitivity_n, "."
  )
}, character(1))

report <- c(
  "# Noise Zero Value Sensitivity Analysis",
  "",
  "## Scope and unresolved metadata limitation",
  "",
  "The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.",
  "",
  "The primary analysis retains `Noise == 0` and excludes only missing or non-finite Noise values. The sensitivity analysis excludes `Noise == 0`. Neither analysis modifies the raw source file or converts zero values to missing values.",
  "",
  "## Zero value distribution",
  "",
  paste0("There are ", total_zero$zero_count, " zero records among ", total_zero$primary_n, " non-missing Noise records (", fmt(total_zero$zero_percent, 4), "%)."),
  paste0("The highest sensor-specific zero percentage is ", fmt(top_zero_sensor$zero_percent, 4), "% at `", top_zero_sensor$group_value, "` (", top_zero_sensor$zero_count, " records)."),
  paste0("The largest annual zero count is ", top_zero_year$zero_count, " in ", top_zero_year$group_value, "; the largest hourly zero count is ", top_zero_hour$zero_count, " at ", sprintf("%02d:00", as.integer(top_zero_hour$group_value)), "."),
  "",
  "The CSV reports zero counts and percentages overall, by sensor, by year, by local hour and for daytime/night-time. Concentration is descriptive and does not establish whether zeros are measurements, faults or missing-value codes.",
  "",
  "## Descriptive sensitivity results",
  "",
  paste0("The maximum absolute hourly median difference is ", fmt(max(hour_results$absolute_difference, na.rm = TRUE), 4), " dataset units."),
  paste0("The maximum absolute weekday median difference is ", fmt(max(weekday_results$absolute_difference, na.rm = TRUE), 4), " dataset units."),
  paste0("The maximum absolute sensor-median difference is ", fmt(max(sensor_results$absolute_difference, na.rm = TRUE), 4), " dataset units. The sensor ordering is ", if (ranking_stable) "unchanged" else "not identical", "."),
  paste0("The 2025 night-time median is ", fmt(night_result$primary_estimate, 4), " with zeros retained and ", fmt(night_result$sensitivity_estimate, 4), " after zero exclusion (absolute difference ", fmt(night_result$absolute_difference, 4), "; n=", night_result$primary_n, "/", night_result$sensitivity_n, ")."),
  "",
  "## 500 m urban activity associations",
  "",
  "The models reproduce the existing 2025 specification: one row per monitored noise sensor, 500 m as the primary buffer, 18:00-05:59 night-time Noise median as the outcome, pedestrian activity as the main predictor, and the optional bar-capacity adjustment as a lagged 2024 contextual baseline, not a 2025 measurement.",
  "",
  association_lines,
  "",
  "## Interpretation",
  "",
  paste0("In the observed snapshot, excluding zero records changes hourly and sensor medians by no more than ", fmt(max(c(hour_results$absolute_difference, sensor_results$absolute_difference), na.rm = TRUE), 4), " dataset units, leaves the sensor ordering ", if (ranking_stable) "unchanged" else "not identical", ", and changes the reported 500 m association estimates by at most ", fmt(max(association_results$absolute_difference, na.rm = TRUE), 6), ". The main temporal, sensor-ranking and urban-activity conclusions are therefore robust to zero-value exclusion in this dataset."),
  "",
  "The observed primary and zero-excluded estimates should be read side by side. Excluding zeros does not justify treating zeros as errors. Conclusions remain limited to the monitored locations and describe exploratory associations rather than causal, health, regulatory or city-wide effects.",
  "",
  "Detailed estimates, sample sizes, absolute differences, relative differences where defined, ranks and zero distributions are in `data/processed/noise_zero_value_sensitivity.csv`."
)
writeLines(report, report_path, useBytes = TRUE)

message("Created ", output_path, " with ", nrow(result), " unique result rows.")
message("Created ", report_path, ".")
