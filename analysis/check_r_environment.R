options(stringsAsFactors = FALSE, scipen = 999)

if (!file.exists(file.path("renv", "activate.R")) || !file.exists("renv.lock")) {
  stop("Run this check from the repository root; renv files are missing.", call. = FALSE)
}

expected_r <- "4.5.2"
if (!identical(paste(R.version$major, R.version$minor, sep = "."), expected_r)) {
  stop(
    "R version mismatch: expected ", expected_r, ", found ", R.version.string,
    call. = FALSE
  )
}

# An already-restored working copy can supply renv before network bootstrap.
project_libraries <- Sys.glob(file.path("renv", "library", "*", "R-*", "*"))
project_libraries <- project_libraries[
  dir.exists(project_libraries) &
    file.exists(file.path(project_libraries, "renv", "DESCRIPTION"))
]
if (length(project_libraries)) {
  .libPaths(c(normalizePath(project_libraries, winslash = "/"), .libPaths()))
}

source(file.path("renv", "activate.R"), local = FALSE)

expected_packages <- c(
  renv = "1.2.4",
  dplyr = "1.2.1",
  tidyr = "1.3.2",
  readr = "2.2.0",
  sf = "1.1-3",
  ggplot2 = "4.0.3"
)

problems <- character()
for (package in names(expected_packages)) {
  if (!requireNamespace(package, quietly = TRUE)) {
    problems <- c(problems, paste0(package, " is not installed"))
    next
  }
  installed <- as.character(utils::packageVersion(package))
  if (utils::packageVersion(package) != base::numeric_version(expected_packages[[package]])) {
    problems <- c(
      problems,
      paste0(package, " expected ", expected_packages[[package]], ", found ", installed)
    )
  }
}

renv::status()
if (length(problems)) {
  stop("R environment check failed: ", paste(problems, collapse = "; "), call. = FALSE)
}

message("R environment check passed: R ", expected_r, "; renv and core package versions match renv.lock.")
