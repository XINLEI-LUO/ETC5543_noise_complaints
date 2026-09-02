options(stringsAsFactors = FALSE, scipen = 999)

# Diagnose repeated device/timestamp keys without deleting or rewriting raw data.
# Sensitivity rule: retain one identical value; otherwise use the finite-value
# median for that device/timestamp. If every repeated value is missing, retain NA.

raw_path <- file.path("data", "raw", "microclimate_sensors.csv")
current_path <- file.path("data", "processed", "noise_outcomes_for_integration.csv")
diagnostic_path <- file.path("data", "processed", "noise_duplicate_timestamp_diagnostics.csv")
comparison_path <- file.path("data", "processed", "noise_deduplication_sensitivity_comparison.csv")
melbourne_tz <- "Australia/Melbourne"

if (!file.exists(raw_path) || !file.exists(current_path)) stop("Required raw data or current integration outcomes are missing.")
raw <- read.csv(raw_path, check.names = FALSE, na.strings = c("", "NA", "null"))
names(raw)[1] <- sub("^\\ufeff|^\\xef\\xbb\\xbf", "", names(raw)[1])
required <- c("Device_id", "Time", "SensorLocation", "LatLong", "Noise")
missing <- setdiff(required, names(raw))
if (length(missing)) stop("Raw fields missing: ", paste(missing, collapse = ", "))
raw$Noise <- suppressWarnings(as.numeric(raw$Noise))

key <- paste(raw$Device_id, raw$Time, sep = "\r")
duplicate_mask <- duplicated(key) | duplicated(key, fromLast = TRUE)
duplicate_indices <- split(which(duplicate_mask), key[duplicate_mask])

classify_group <- function(idx) {
  values <- raw$Noise[idx]
  states <- ifelse(is.na(values), "__MISSING__", format(values, digits = 17, scientific = FALSE))
  finite_values <- values[is.finite(values)]
  data.frame(
    device_id = raw$Device_id[idx[1]], duplicated_timestamp_group = 1L,
    duplicate_rows = length(idx), excess_rows = length(idx) - 1L,
    exact_duplicate_excess_rows = sum(duplicated(raw[idx, , drop = FALSE])),
    identical_noise = as.integer(length(unique(states)) == 1L),
    conflicting_noise = as.integer(length(unique(states)) > 1L),
    maximum_noise_difference = if (length(finite_values) >= 2L) diff(range(finite_values)) else 0,
    stringsAsFactors = FALSE
  )
}

group_diagnostics <- do.call(rbind, lapply(duplicate_indices, classify_group))
sensor_diagnostics <- do.call(rbind, lapply(split(group_diagnostics, group_diagnostics$device_id), function(z) {
  data.frame(
    device_id = z$device_id[1],
    duplicated_timestamp_groups = sum(z$duplicated_timestamp_group),
    duplicate_rows = sum(z$duplicate_rows), excess_rows = sum(z$excess_rows),
    exact_duplicate_excess_rows = sum(z$exact_duplicate_excess_rows),
    groups_with_identical_noise = sum(z$identical_noise),
    groups_with_conflicting_noise = sum(z$conflicting_noise),
    maximum_within_timestamp_noise_difference = max(z$maximum_noise_difference),
    stringsAsFactors = FALSE
  )
}))
rownames(sensor_diagnostics) <- NULL
sensor_diagnostics <- sensor_diagnostics[order(sensor_diagnostics$device_id), ]
write.csv(sensor_diagnostics, diagnostic_path, row.names = FALSE, na = "")

# Construct the sensitivity dataset in memory only.
keep <- rep(TRUE, nrow(raw))
sensitivity_noise <- raw$Noise
for (idx in duplicate_indices) {
  finite_values <- raw$Noise[idx][is.finite(raw$Noise[idx])]
  sensitivity_noise[idx[1]] <- if (length(finite_values)) median(finite_values) else NA_real_
  keep[idx[-1]] <- FALSE
}
sensitivity <- raw[keep, c("Device_id", "Time"), drop = FALSE]
sensitivity$Noise <- sensitivity_noise[keep]

time_normalized <- sub("([+-][0-9]{2}):([0-9]{2})$", "\\1\\2", sensitivity$Time)
sensitivity$timestamp <- as.POSIXct(time_normalized, format = "%Y-%m-%dT%H:%M:%S%z", tz = melbourne_tz)
if (anyNA(sensitivity$timestamp)) stop("Sensitivity timestamps failed to parse.")
sensitivity$hour <- as.integer(format(sensitivity$timestamp, "%H", tz = melbourne_tz))
sensitivity$weekday_num <- as.integer(format(sensitivity$timestamp, "%u", tz = melbourne_tz))
safe_median <- function(x) { x <- x[is.finite(x)]; if (length(x)) median(x) else NA_real_ }

usable_ids <- unique(sensitivity$Device_id[is.finite(sensitivity$Noise)])
sensitivity_outcomes <- do.call(rbind, lapply(sort(usable_ids), function(device_id) {
  z <- sensitivity[sensitivity$Device_id == device_id, , drop = FALSE]
  daytime <- z$hour >= 6L & z$hour < 18L
  weekday <- z$weekday_num <= 5L
  data.frame(
    device_id = device_id,
    overall_median_noise = safe_median(z$Noise),
    daytime_median_noise = safe_median(z$Noise[daytime]),
    nighttime_median_noise = safe_median(z$Noise[!daytime]),
    weekday_median_noise = safe_median(z$Noise[weekday]),
    weekend_median_noise = safe_median(z$Noise[!weekday]), stringsAsFactors = FALSE
  )
}))

current <- read.csv(current_path, na.strings = c("", "NA"), check.names = FALSE)
outcomes <- c("overall_median_noise", "daytime_median_noise", "nighttime_median_noise", "weekday_median_noise", "weekend_median_noise")
comparison_wide <- merge(current[c("device_id", outcomes)], sensitivity_outcomes,
                         by = "device_id", suffixes = c("_current", "_sensitivity"), all = TRUE)
comparison <- do.call(rbind, lapply(outcomes, function(outcome) {
  current_values <- comparison_wide[[paste0(outcome, "_current")]]
  sensitivity_values <- comparison_wide[[paste0(outcome, "_sensitivity")]]
  data.frame(device_id = comparison_wide$device_id, outcome = outcome,
             current_value = current_values, sensitivity_value = sensitivity_values,
             absolute_difference = abs(current_values - sensitivity_values), stringsAsFactors = FALSE)
}))
comparison <- comparison[order(comparison$device_id, match(comparison$outcome, outcomes)), ]
rownames(comparison) <- NULL
write.csv(comparison, comparison_path, row.names = FALSE, na = "")

message("Duplicate timestamp diagnostic complete.")
message("Rows in duplicated keys: ", sum(duplicate_mask), "; groups: ", length(duplicate_indices),
        "; excess rows: ", sum(sensor_diagnostics$excess_rows))
message("Exact duplicate excess rows: ", sum(sensor_diagnostics$exact_duplicate_excess_rows),
        "; identical-Noise groups: ", sum(sensor_diagnostics$groups_with_identical_noise),
        "; conflicting-Noise groups: ", sum(sensor_diagnostics$groups_with_conflicting_noise))
message("Maximum absolute median-outcome difference: ", max(comparison$absolute_difference, na.rm = TRUE))
