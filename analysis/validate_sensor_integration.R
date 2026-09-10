options(stringsAsFactors = FALSE, scipen = 999)

project_library <- normalizePath(".r-library", winslash = "/", mustWork = FALSE)
if (dir.exists(project_library)) .libPaths(c(project_library, .libPaths()))

# Run from the project root after the preparation and integration scripts.
processed_dir <- file.path("data", "processed")
required_outputs <- c(
  "noise_outcomes_for_integration.csv",
  "noise_duplicate_timestamp_diagnostics.csv",
  "noise_deduplication_sensitivity_comparison.csv",
  "integrated_sensor_250m.csv", "integrated_sensor_500m.csv",
  "integrated_sensor_1000m.csv", "integrated_sensor_all_buffers.csv",
  "integration_join_diagnostics.csv"
)
required_paths <- file.path(processed_dir, required_outputs)
missing_outputs <- required_paths[!file.exists(required_paths)]
if (!file.exists(file.path("figures", "sensor_buffer_integration_map.png"))) {
  missing_outputs <- c(missing_outputs, file.path("figures", "sensor_buffer_integration_map.png"))
}
if (length(missing_outputs)) stop("Required outputs are missing: ", paste(missing_outputs, collapse = ", "))

fail <- function(condition, message) if (!isTRUE(condition)) stop(message, call. = FALSE)
is_nonnegative_integer_or_na <- function(x) all(is.na(x) | (is.finite(x) & x >= 0 & x == floor(x)))

noise <- read.csv(required_paths[1], na.strings = c("", "NA"), check.names = FALSE)
all_buffers <- read.csv(file.path(processed_dir, "integrated_sensor_all_buffers.csv"), na.strings = c("", "NA"), check.names = FALSE)
fail(nrow(noise) == 11L, "Noise outcomes must have exactly 11 rows.")
fail(!anyDuplicated(noise$device_id), "Noise device IDs are not unique.")
fail(!"aws5-0999" %in% noise$device_id, "aws5-0999 must be absent from analysis outputs.")
fail(nrow(all_buffers) == 33L, "All-buffer output must have exactly 33 rows.")
fail(setequal(unique(all_buffers$buffer_m), c(250, 500, 1000)), "buffer_m must contain exactly 250, 500 and 1000.")
fail(all(table(all_buffers$device_id) == 3L), "Every sensor must occur exactly three times.")
fail(!anyDuplicated(all_buffers[c("device_id", "buffer_m")]), "Duplicate device_id + buffer_m keys found.")
for (distance in c(250, 500, 1000)) {
  one <- read.csv(file.path(processed_dir, paste0("integrated_sensor_", distance, "m.csv")), na.strings = c("", "NA"))
  fail(nrow(one) == 11L && all(one$buffer_m == distance), paste0(distance, " m output is invalid."))
}
fail(all(noise$longitude >= 144 & noise$longitude <= 146 & noise$latitude >= -39 & noise$latitude <= -37), "Coordinates are outside plausible Melbourne WGS84 bounds.")
fail(all(noise$coverage_ratio >= 0 & noise$coverage_ratio <= 1), "coverage_ratio is outside [0, 1].")

duplicate_diagnostics <- read.csv(file.path(processed_dir, "noise_duplicate_timestamp_diagnostics.csv"), na.strings = c("", "NA"))
fail(sum(duplicate_diagnostics$duplicate_rows) == 5496L, "Duplicated-key row total differs from 5,496.")
fail(sum(duplicate_diagnostics$duplicated_timestamp_groups) == 2745L, "Duplicated timestamp group total must be 2,745.")
fail(sum(duplicate_diagnostics$excess_rows) == 2751L, "Duplicated timestamp excess-row total must be 2,751.")
fail(sum(duplicate_diagnostics$exact_duplicate_excess_rows) == 0L, "Unexpected exact duplicate rows found.")
fail(sum(duplicate_diagnostics$groups_with_identical_noise) == 59L, "Identical-Noise group total must be 59.")
fail(sum(duplicate_diagnostics$groups_with_conflicting_noise) == 2686L, "Conflicting-Noise group total must be 2,686.")
fail(
  all(duplicate_diagnostics$groups_with_identical_noise + duplicate_diagnostics$groups_with_conflicting_noise ==
        duplicate_diagnostics$duplicated_timestamp_groups),
  "Identical/conflicting Noise classifications do not cover every duplicated timestamp group."
)

sensitivity <- read.csv(file.path(processed_dir, "noise_deduplication_sensitivity_comparison.csv"), na.strings = c("", "NA"))
fail(nrow(sensitivity) == 55L, "Sensitivity comparison must contain 11 sensors x 5 outcomes = 55 rows.")
fail(all(sensitivity$absolute_difference >= 0), "Sensitivity absolute differences must be non-negative.")
max_sensitivity_difference <- max(sensitivity$absolute_difference, na.rm = TRUE)
fail(max_sensitivity_difference <= 0.1 + 1e-10,
     "Deduplication sensitivity exceeds the verified 0.1 dataset-unit bound; review whether main outcomes should change.")

hour <- read.csv(file.path(processed_dir, "noise_sensor_hour.csv"), na.strings = c("", "NA"))
day <- read.csv(file.path(processed_dir, "noise_sensor_day.csv"), na.strings = c("", "NA"))
for (x in list(hour = hour, day = day)) {
  fail(all(x$coverage_ratio >= 0 & x$coverage_ratio <= 1), "Hour/day coverage_ratio is outside [0, 1].")
  fail(all(abs(x$coverage_ratio - x$unique_coverage_ratio) <= 1e-12), "Hour/day coverage_ratio must use unique valid timestamps.")
}
count_fields <- grep("^n_|_seats$", names(all_buffers), value = TRUE)
fail(all(vapply(all_buffers[count_fields], is_nonnegative_integer_or_na, logical(1))), "Count/seating fields must be non-negative integers or NA.")

outcome_fields <- c("overall_median_noise", "daytime_median_noise", "nighttime_median_noise", "weekday_median_noise", "weekend_median_noise")
for (field in outcome_fields) {
  stable <- tapply(all_buffers[[field]], all_buffers$device_id, function(x) length(unique(x[!is.na(x)])) <= 1L)
  fail(all(stable), paste0(field, " changes across buffer distances."))
}

feature_counts <- intersect(c("n_bars", "n_cafes", "indoor_seats", "outdoor_seats"), names(all_buffers))
monotonic_exceptions <- character()
for (field in feature_counts) for (id in unique(all_buffers$device_id)) {
  x <- all_buffers[all_buffers$device_id == id, c("buffer_m", field)]
  x <- x[order(x$buffer_m), ]
  if (any(diff(x[[field]]) < 0, na.rm = TRUE)) monotonic_exceptions <- c(monotonic_exceptions, paste(id, field, sep = ":"))
}
if (length(monotonic_exceptions)) warning("Non-decreasing feature-count exceptions: ", paste(monotonic_exceptions, collapse = ", "))

audit <- read.csv(file.path(processed_dir, "noise_sensor_audit.csv"), na.strings = c("", "NA"))
excluded <- audit[audit$device_id == "aws5-0999", ]
fail(nrow(excluded) == 1L && !excluded$is_usable_noise_sensor && excluded$n_valid_noise == 0L, "aws5-0999 exclusion is not documented correctly.")

coverage <- read.csv(file.path(processed_dir, "sensor_coverage_summary.csv"), na.strings = c("", "NA"))
comparison <- merge(noise, coverage, by.x = "device_id", by.y = "Device_id", all.x = TRUE)
fail(all(comparison$n_valid_noise == comparison$valid_noise), "Valid observation counts differ from sensor_coverage_summary.csv.")
tolerance <- 1e-10
fail(all(abs(comparison$overall_median_noise - comparison$median_noise) <= tolerance), "Overall medians differ from sensor_coverage_summary.csv.")

message("Validation passed: 11 sensors, 33 sensor-buffer rows, unique keys, stable noise outcomes, and valid count/coverage semantics.")
message(sprintf("Duplicate sensitivity passed: maximum median-outcome difference %.1f dataset units; main outcomes retained.",
                max_sensitivity_difference))
if (!length(monotonic_exceptions)) message("Urban feature counts/seats are non-decreasing with buffer size.")

# Optional CLUE business extension. Existing validation remains unchanged when
# the independently generated CLUE outputs are absent.
clue_feature_path <- file.path(processed_dir, "clue_business_features_by_buffer.csv")
clue_integrated_path <- file.path(processed_dir, "integrated_sensor_all_buffers_with_clue_2024.csv")
clue_qa_path <- file.path(processed_dir, "clue_business_integration_qa.csv")
clue_sensitivity_path <- file.path(processed_dir, "clue_business_duplicate_sensitivity.csv")
clue_paths <- c(clue_feature_path, clue_integrated_path, clue_qa_path, clue_sensitivity_path)

if (any(file.exists(clue_paths)) && !all(file.exists(clue_paths))) {
  stop("Only some CLUE business outputs exist; rerun analysis/prepare_clue_business_features.R.")
}
if (all(file.exists(clue_paths))) {
  clue <- read.csv(clue_feature_path, na.strings = c("", "NA"), check.names = FALSE)
  clue_integrated <- read.csv(clue_integrated_path, na.strings = c("", "NA"), check.names = FALSE)
  clue_qa <- read.csv(clue_qa_path, na.strings = c("", "NA"), check.names = FALSE)
  clue_sensitivity <- read.csv(clue_sensitivity_path, na.strings = c("", "NA"), check.names = FALSE)

  fail(nrow(clue) == 33L && !anyDuplicated(clue[c("device_id", "buffer_m")]),
       "CLUE feature output must contain 33 unique device_id + buffer_m rows.")
  fail(setequal(unique(clue$buffer_m), c(250, 500, 1000)) && all(table(clue$buffer_m) == 11L),
       "CLUE feature output must contain 11 sensors at each expected distance.")
  fail(nrow(clue_integrated) == nrow(all_buffers) &&
         !anyDuplicated(clue_integrated[c("device_id", "buffer_m")]),
       "CLUE integration changed the validated sensor-buffer structure.")
  fail(setequal(paste(clue_integrated$device_id, clue_integrated$buffer_m),
                paste(all_buffers$device_id, all_buffers$buffer_m)),
       "CLUE integration does not preserve all existing sensor-buffer keys.")
  fail(all(clue$feature_data_year == 2024L), "CLUE features must use only Census year 2024.")
  fail(all(clue$business_mix_entropy_normalised >= 0 & clue$business_mix_entropy_normalised <= 1),
       "Normalised business-mix entropy is outside [0, 1].")
  fail(all(clue$business_density_per_km2 >= 0), "Business density cannot be negative.")
  clue_count_fields <- c(
    "total_records", "total_active_businesses", "vacant_spaces", "cafes_restaurants",
    "takeaway_food", "pubs_bars_clue", "other_food_beverage", "retail_businesses",
    "accommodation_businesses", "entertainment_recreation_businesses",
    "professional_scientific_technical_businesses", "financial_insurance_businesses",
    "rental_real_estate_businesses", "administrative_support_businesses"
  )
  fail(all(vapply(clue[clue_count_fields], is_nonnegative_integer_or_na, logical(1))),
       "CLUE count fields must be non-negative integers.")
  for (field in clue_count_fields) for (id in unique(clue$device_id)) {
    values <- clue[clue$device_id == id, c("buffer_m", field)]
    values <- values[order(values$buffer_m), field]
    fail(!any(diff(values) < 0), paste0("CLUE count is not non-decreasing: ", id, " / ", field))
  }
  fail(nrow(clue_sensitivity) == 33L, "CLUE duplicate sensitivity must contain 33 rows.")
  fail(all(clue_sensitivity$active_business_absolute_difference >= 0 &
             clue_sensitivity$entropy_absolute_difference >= 0),
       "CLUE duplicate-sensitivity differences must be non-negative.")
  fail(nrow(clue_qa) == 18L && all(clue_qa$status == "PASS"),
       "CLUE QA table contains a failed or missing check.")
  message("CLUE validation passed: 2024-only features, 33 unique keys, monotonic counts, valid entropy and preserved integration rows.")
}
