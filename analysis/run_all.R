options(stringsAsFactors = FALSE, scipen = 999)

if (!file.exists(file.path("analysis", "run_all.R"))) {
  stop(
    "Run this script from the repository root: Rscript --vanilla analysis/run_all.R",
    call. = FALSE
  )
}

if (!file.exists(file.path("renv", "activate.R"))) {
  stop(
    "renv/activate.R is missing. Restore the repository environment as described in README.md.",
    call. = FALSE
  )
}

# Some Windows automation hosts export the Unix-only locale C.UTF-8. In that
# case R can mis-encode a non-ASCII project path before renv is activated.
if (.Platform$OS.type == "windows" && identical(Sys.getenv("LANG"), "C.UTF-8")) {
  stop(
    "Windows R cannot use the inherited LANG=C.UTF-8 locale in this environment. ",
    "Use `python analysis/run_pipeline.py --check`, or clear LANG and LC_ALL before invoking Rscript.",
    call. = FALSE
  )
}

source(file.path("renv", "activate.R"), local = FALSE)

required_packages <- c("dplyr", "tidyr", "readr", "sf", "ggplot2")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop(
    "Required R packages are missing: ", paste(missing_packages, collapse = ", "),
    ". Run renv::restore() from the repository root; packages are not installed silently.",
    call. = FALSE
  )
}

required_inputs <- c(
  file.path("data", "raw", "microclimate_sensors.csv"),
  file.path("data", "raw", "bars-and-pubs-with-patron-capacity.csv"),
  file.path("data", "raw", "cafes-and-restaurants-with-seating-capacity.csv"),
  file.path("data", "raw", "business-establishments-with-address-and-industry-classification.csv")
)
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs)) {
  stop(
    "Required input files are missing: ", paste(missing_inputs, collapse = ", "),
    ". Recovery instructions and checksums are in data/README.md.",
    call. = FALSE
  )
}

pipeline <- c(
  "analysis/noise_eda.R",
  "analysis/seasonal_noise_analysis.R",
  "analysis/prepare_noise_outcomes.R",
  "analysis/duplicate_timestamp_sensitivity.R",
  "analysis/build_sensor_integration.R",
  "analysis/prepare_clue_business_features.R",
  "analysis/validate_sensor_integration.R"
)

missing_scripts <- pipeline[!file.exists(pipeline)]
if (length(missing_scripts)) {
  stop("Required pipeline scripts are missing: ", paste(missing_scripts, collapse = ", "), call. = FALSE)
}

message("Starting ETC5543 reproducible pipeline.")
message("Existing files in data/processed and figures may be overwritten by their producing scripts.")

for (i in seq_along(pipeline)) {
  script <- pipeline[[i]]
  message(sprintf("[%d/%d] Running %s", i, length(pipeline), script))
  source(script, local = new.env(parent = globalenv()), chdir = FALSE)
  message(sprintf("[%d/%d] Completed %s", i, length(pipeline), script))
}

message("ETC5543 pipeline completed successfully, including final validation.")
