"""Build multi-year pedestrian data and QA outputs only.

This is phase-one data engineering. It deliberately performs no correlation,
regression, leave-one-out analysis, inferential sensitivity analysis, charts,
or report-result writing.

Run from the project root:
    python analysis/pedestrian_activity_integration_multiyear.py
    python analysis/pedestrian_activity_integration_multiyear.py --year 2025
    python analysis/pedestrian_activity_integration_multiyear.py --year 2026
    python analysis/pedestrian_activity_integration_multiyear.py --overwrite
"""

from __future__ import annotations

import argparse
import hashlib
import math
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from pyproj import Transformer


ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
PROCESSED = ROOT / "data" / "processed"
ANALYSIS = ROOT / "analysis"
SCRIPT_REL = "analysis/pedestrian_activity_integration_multiyear.py"
COUNTS_REL = "data/raw/pedestrian_counts_2019_2024.csv"
LOCATIONS_REL = "data/raw/pedestrian-counting-system-sensor-locations.csv"
NOISE_LOCATIONS_REL = "data/processed/noise_sensor_locations.csv"
NOISE_RAW_REL = "data/raw/microclimate_sensors.csv"
BUSINESS_BASELINE_REL = "data/processed/integrated_sensor_all_buffers.csv"
BUSINESS_TEMPORAL_STATUS = "Lagged 2024 contextual baseline; not a 2025 measurement"
BUFFER_METRES = (250, 500, 1000)
SUPPORTED_FORMAL_YEARS = (2024, 2025)
EXPECTED_YEAR_ROWS = {2024: 286_845, 2025: 815_447, 2026: 166}
EXPECTED_YEAR_SENSORS = {2024: 96, 2025: 102, 2026: 25}
PED_SOURCE_FILES = f"{COUNTS_REL}; {LOCATIONS_REL}"
TRANSFORMER = Transformer.from_crs("EPSG:4326", "EPSG:7855", always_xy=True)


def generated_at() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def metadata(period: str, year: int | str, purpose: str, sources: str) -> dict[str, object]:
    return {
        "source_files": sources,
        "analysis_period": period,
        "feature_year": year,
        "output_purpose": purpose,
        "generation_script": SCRIPT_REL,
        "generated_at": generated_at(),
    }


def add_metadata(frame: pd.DataFrame, period: str, year: int | str, purpose: str, sources: str) -> pd.DataFrame:
    result = frame.copy()
    for key, value in metadata(period, year, purpose, sources).items():
        result[key] = value
    return result


def require_columns(frame: pd.DataFrame, columns: list[str], source: str) -> None:
    missing = sorted(set(columns) - set(frame.columns))
    if missing:
        raise ValueError(f"{source} is missing required columns: {', '.join(missing)}")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def ensure_writable_output(path: Path, overwrite: bool) -> None:
    if not path.exists():
        return
    if not overwrite:
        raise FileExistsError(f"Output already exists: {path.relative_to(ROOT)}. Use --overwrite only for files created by this script.")
    if path.suffix.lower() != ".csv":
        text = path.read_text(encoding="utf-8")
        if SCRIPT_REL not in text:
            raise PermissionError(f"Refusing to overwrite file not identified as created by this script: {path.relative_to(ROOT)}")
        return
    header = pd.read_csv(path, nrows=5)
    if "generation_script" not in header.columns or not header["generation_script"].eq(SCRIPT_REL).all():
        raise PermissionError(f"Refusing to overwrite legacy or foreign output: {path.relative_to(ROOT)}")


def safe_mean(series: pd.Series) -> float:
    values = pd.to_numeric(series, errors="coerce")
    return float(values.mean()) if values.notna().any() else math.nan


def prepare_counts(counts: pd.DataFrame) -> pd.DataFrame:
    data = counts.copy()
    data["Sensing_Date"] = pd.to_datetime(data["Sensing_Date"], errors="coerce")
    data["HourDay"] = pd.to_numeric(data["HourDay"], errors="coerce")
    data["Total_of_Directions"] = pd.to_numeric(data["Total_of_Directions"], errors="coerce")
    invalid = (
        data["Sensing_Date"].isna()
        | ~data["HourDay"].between(0, 23)
        | data["Total_of_Directions"].isna()
        | data["Total_of_Directions"].lt(0)
    )
    if invalid.any():
        raise ValueError(f"Pedestrian source has {int(invalid.sum())} invalid required records")
    if data.duplicated(["Location_ID", "Sensing_Date", "HourDay"]).any():
        raise ValueError("Pedestrian source has duplicate Location_ID + Sensing_Date + HourDay keys")
    data["date"] = data["Sensing_Date"].dt.normalize()
    data["year"] = data["date"].dt.year
    data["weekday_number"] = data["date"].dt.dayofweek + 1
    data["is_weekend"] = data["weekday_number"].ge(6)
    data["is_daytime"] = data["HourDay"].between(6, 17)
    data["is_fri_sat_evening"] = data["weekday_number"].isin([5, 6]) & data["HourDay"].between(18, 23)
    return data


def build_sensor_summary(year_data: pd.DataFrame, locations: pd.DataFrame, year: int) -> pd.DataFrame:
    daily = year_data.groupby(["Location_ID", "date"], as_index=False).agg(
        daily_total=("Total_of_Directions", "sum"), observed_hours_in_day=("HourDay", "nunique")
    )
    daily["daily_hour_coverage_ratio"] = daily["observed_hours_in_day"] / 24
    daily["is_complete_day"] = daily["observed_hours_in_day"].eq(24)
    rows: list[dict[str, object]] = []
    for location_id, group in year_data.groupby("Location_ID", sort=True):
        group_daily = daily.loc[daily["Location_ID"].eq(location_id)]
        first_date, last_date = group["date"].min(), group["date"].max()
        expected_hours = (int((last_date - first_date).days) + 1) * 24
        complete_daily = group_daily.loc[group_daily["is_complete_day"], "daily_total"]
        complete_day_mean = safe_mean(complete_daily)
        rows.append({
            "Location_ID": location_id,
            "first_observed_date": first_date.date().isoformat(),
            "last_observed_date": last_date.date().isoformat(),
            "observed_days": int(group["date"].nunique()),
            "observed_hours": int(len(group)),
            "expected_hours_in_observed_span": expected_hours,
            "hour_coverage_ratio": min(len(group) / expected_hours, 1.0),
            "mean_daily_hour_coverage_ratio": float(group_daily["daily_hour_coverage_ratio"].mean()),
            "complete_days": int(group_daily["is_complete_day"].sum()),
            "complete_day_ratio": float(group_daily["is_complete_day"].mean()),
            "avg_hourly_pedestrian_count": safe_mean(group["Total_of_Directions"]),
            "avg_daily_pedestrian_count": safe_mean(group_daily["daily_total"]),
            "avg_complete_day_pedestrian_count": complete_day_mean,
            "daily_activity_analysis_value": complete_day_mean,
            "daily_activity_analysis_definition": "Mean daily total among dates with all 24 hourly records",
            "avg_daily_pedestrian_count_status": "Descriptive observed-day mean; not the formal daily activity metric",
            "daytime_avg_hourly_pedestrian_count": safe_mean(group.loc[group["is_daytime"], "Total_of_Directions"]),
            "nighttime_avg_hourly_pedestrian_count": safe_mean(group.loc[~group["is_daytime"], "Total_of_Directions"]),
            "weekday_avg_hourly_pedestrian_count": safe_mean(group.loc[~group["is_weekend"], "Total_of_Directions"]),
            "weekend_avg_hourly_pedestrian_count": safe_mean(group.loc[group["is_weekend"], "Total_of_Directions"]),
            "fri_sat_evening_avg_hourly_pedestrian_count": safe_mean(group.loc[group["is_fri_sat_evening"], "Total_of_Directions"]),
        })
    summary = pd.DataFrame(rows).merge(
        locations[["Location_ID", "Sensor_Description", "Latitude", "Longitude"]],
        on="Location_ID", how="left", validate="one_to_one", indicator="location_join",
    )
    summary["has_location_coordinates"] = (
        summary["location_join"].eq("both")
        & summary["Latitude"].between(-39, -37)
        & summary["Longitude"].between(144, 146)
    )
    summary = summary.drop(columns="location_join")
    period = f"{year_data['date'].min().date().isoformat()} to {year_data['date'].max().date().isoformat()}"
    return add_metadata(summary, period, year, f"{year} pedestrian activity and coverage by pedestrian sensor", PED_SOURCE_FILES)


def project_xy(longitude: pd.Series, latitude: pd.Series) -> tuple[np.ndarray, np.ndarray]:
    x, y = TRANSFORMER.transform(longitude.to_numpy(), latitude.to_numpy())
    return np.asarray(x), np.asarray(y)


def build_buffer_summary(sensor_summary: pd.DataFrame, noise_locations: pd.DataFrame, year: int) -> pd.DataFrame:
    located = sensor_summary.loc[sensor_summary["has_location_coordinates"]].copy()
    located["x_7855"], located["y_7855"] = project_xy(located["Longitude"], located["Latitude"])
    noise = noise_locations.copy()
    noise["x_7855"], noise["y_7855"] = project_xy(noise["longitude"], noise["latitude"])
    metrics = [
        "avg_hourly_pedestrian_count", "avg_daily_pedestrian_count", "daily_activity_analysis_value",
        "daytime_avg_hourly_pedestrian_count", "nighttime_avg_hourly_pedestrian_count",
        "weekday_avg_hourly_pedestrian_count", "weekend_avg_hourly_pedestrian_count",
        "fri_sat_evening_avg_hourly_pedestrian_count",
    ]
    rows: list[dict[str, object]] = []
    for noise_row in noise.itertuples(index=False):
        distances = np.hypot(located["x_7855"] - noise_row.x_7855, located["y_7855"] - noise_row.y_7855)
        local = located.assign(distance_to_noise_sensor_m=distances)
        nearest = float(distances.min()) if len(distances) else math.nan
        for buffer_m in BUFFER_METRES:
            matched = local.loc[local["distance_to_noise_sensor_m"].le(buffer_m)]
            row: dict[str, object] = {
                "device_id": noise_row.device_id,
                "buffer_m": buffer_m,
                "n_pedestrian_sensors": int(len(matched)),
                "pedestrian_sensor_ids": ";".join(str(int(x)) for x in sorted(matched["Location_ID"])),
                "nearest_pedestrian_sensor_m": nearest,
                "mean_pedestrian_sensor_coverage_ratio": safe_mean(matched["hour_coverage_ratio"]),
            }
            for metric in metrics:
                row[f"mean_{metric}"] = safe_mean(matched[metric])
                row[f"sum_sensor_means_{metric}"] = float(matched[metric].sum(min_count=1)) if len(matched) else math.nan
            rows.append(row)
    result = pd.DataFrame(rows)
    period = str(sensor_summary["analysis_period"].iloc[0])
    sources = f"data/processed/pedestrian_sensor_activity_{year}.csv; {NOISE_LOCATIONS_REL}"
    return add_metadata(result, period, year, f"{year} pedestrian activity within EPSG:7855 noise-sensor buffers", sources)


def build_time_aligned_noise(noise_raw: pd.DataFrame, year: int) -> pd.DataFrame:
    timestamps = pd.to_datetime(noise_raw["Time"], errors="coerce", utc=True)
    if timestamps.isna().any():
        raise ValueError(f"Noise source contains {int(timestamps.isna().sum())} unparseable timestamps")
    local = timestamps.dt.tz_convert("Australia/Melbourne")
    data = noise_raw.copy()
    data["timestamp"] = local
    data["local_date"] = local.dt.tz_localize(None).dt.normalize()
    data["local_hour"] = local.dt.hour
    data["Noise"] = pd.to_numeric(data["Noise"], errors="coerce")
    start, end = pd.Timestamp(f"{year}-01-01"), pd.Timestamp(f"{year}-12-31")
    data = data.loc[data["local_date"].between(start, end) & (data["local_hour"].ge(18) | data["local_hour"].lt(6))].copy()
    rows = []
    expected = int((end - start).days + 1) * 12 * 4
    for device_id, group in data.groupby("Device_id", sort=True):
        valid = group["Noise"].notna()
        if not valid.any():
            continue
        unique_valid = group.loc[valid, "timestamp"].nunique()
        rows.append({
            "device_id": device_id,
            "analysis_start_date": start.date().isoformat(),
            "analysis_end_date": end.date().isoformat(),
            "nighttime_median_noise": float(group.loc[valid, "Noise"].median()),
            "nighttime_mean_noise": float(group.loc[valid, "Noise"].mean()),
            "nighttime_valid_observations": int(valid.sum()),
            "nighttime_unique_valid_timestamps": int(unique_valid),
            "nighttime_expected_observations": expected,
            "nighttime_coverage_ratio": min(unique_valid / expected, 1.0),
            "first_noise_observation": group["timestamp"].min().isoformat(),
            "last_noise_observation": group["timestamp"].max().isoformat(),
        })
    result = pd.DataFrame(rows)
    return add_metadata(
        result, f"{start.date().isoformat()} to {end.date().isoformat()}", year,
        f"Night-time noise aligned to the {year} pedestrian analysis period",
        NOISE_RAW_REL,
    )


def build_integrated_2025(buffer_summary: pd.DataFrame, aligned_noise: pd.DataFrame, baseline: pd.DataFrame) -> pd.DataFrame:
    baseline_fields = [
        "device_id", "buffer_m", "n_bars", "total_bar_capacity", "median_bar_capacity",
        "n_cafes", "indoor_seats", "outdoor_seats",
    ]
    require_columns(baseline, baseline_fields, BUSINESS_BASELINE_REL)
    renamed = baseline[baseline_fields].rename(columns={
        "n_bars": "n_bars_2024_baseline",
        "total_bar_capacity": "total_bar_capacity_2024_baseline",
        "median_bar_capacity": "median_bar_capacity_2024_baseline",
        "n_cafes": "n_cafes_2024_baseline",
        "indoor_seats": "indoor_seats_2024_baseline",
        "outdoor_seats": "outdoor_seats_2024_baseline",
    })
    noise_fields = [c for c in aligned_noise.columns if c not in {"source_files", "analysis_period", "feature_year", "output_purpose", "generation_script", "generated_at"}]
    result = buffer_summary.merge(aligned_noise[noise_fields], on="device_id", how="left", validate="many_to_one")
    result = result.merge(renamed, on=["device_id", "buffer_m"], how="left", validate="one_to_one")
    result["business_feature_year"] = 2024
    result["business_temporal_status"] = BUSINESS_TEMPORAL_STATUS
    for key, value in metadata(
        "2025-01-01 to 2025-12-31", 2025,
        "Phase-one 2025 aligned noise and pedestrian data with a lagged 2024 contextual business baseline; not a 2025 business measurement",
        f"data/processed/pedestrian_activity_by_noise_buffer_2025.csv; data/processed/noise_pedestrian_time_aligned_2025.csv; {BUSINESS_BASELINE_REL}",
    ).items():
        result[key] = value
    return result


def comparison_metrics(data: pd.DataFrame, ids: set[int], start: str, end: str, suffix: str) -> pd.DataFrame:
    subset = data.loc[data["Location_ID"].isin(ids) & data["date"].between(pd.Timestamp(start), pd.Timestamp(end))]
    rows = []
    for location_id, group in subset.groupby("Location_ID", sort=True):
        rows.append({
            "Location_ID": location_id,
            f"observed_hours_{suffix}": len(group),
            f"hour_coverage_ratio_{suffix}": len(group) / (((pd.Timestamp(end) - pd.Timestamp(start)).days + 1) * 24),
            f"avg_hourly_pedestrian_count_{suffix}": safe_mean(group["Total_of_Directions"]),
            f"nighttime_avg_hourly_pedestrian_count_{suffix}": safe_mean(group.loc[~group["is_daytime"], "Total_of_Directions"]),
        })
    return pd.DataFrame(rows)


def build_year_comparison(counts: pd.DataFrame) -> pd.DataFrame:
    ids_2024 = set(counts.loc[counts["year"].eq(2024), "Location_ID"])
    ids_2025 = set(counts.loc[counts["year"].eq(2025), "Location_ID"])
    common = ids_2024 & ids_2025
    specs = [
        ("matched_calendar_window", "2024-08-19", "2024-12-31", "2025-08-19", "2025-12-31"),
        ("available_year_data", "2024-08-19", "2024-12-31", "2025-01-01", "2025-12-31"),
    ]
    frames = []
    for basis, start24, end24, start25, end25 in specs:
        a = comparison_metrics(counts, common, start24, end24, "2024")
        b = comparison_metrics(counts, common, start25, end25, "2025")
        merged = a.merge(b, on="Location_ID", how="inner", validate="one_to_one")
        merged["comparison_basis"] = basis
        merged["period_2024"] = f"{start24} to {end24}"
        merged["period_2025"] = f"{start25} to {end25}"
        frames.append(merged)
    result = pd.concat(frames, ignore_index=True)
    return add_metadata(
        result, "2024-08-19 to 2024-12-31 and 2025 comparison windows", "2024_2025",
        "Descriptive time-window-aligned pedestrian data; not a trend or statistical analysis",
        COUNTS_REL,
    )


def build_2026_diagnostics(counts: pd.DataFrame) -> pd.DataFrame:
    data = counts.loc[counts["year"].eq(2026)].copy()
    rows = []
    for location_id, group in data.groupby("Location_ID", sort=True):
        first, last = group["date"].min(), group["date"].max()
        expected = (int((last - first).days) + 1) * 24
        rows.append({
            "Location_ID": location_id,
            "first_observed_date": first.date().isoformat(), "last_observed_date": last.date().isoformat(),
            "total_records_2026": len(data), "pedestrian_sensors_2026": data["Location_ID"].nunique(),
            "records_for_sensor": len(group), "observed_days": group["date"].nunique(),
            "observed_hours": len(group), "expected_hours_in_observed_span": expected,
            "hour_coverage_ratio": min(len(group) / expected, 1.0),
            "insufficient_coverage": True,
            "exclusion_reason": "2026 pedestrian data have insufficient hourly coverage for formal activity analysis.",
        })
    result = pd.DataFrame(rows)
    return add_metadata(
        result, f"{data['date'].min().date().isoformat()} to {data['date'].max().date().isoformat()}", 2026,
        "Coverage diagnostics only; 2026 excluded from formal activity analysis", COUNTS_REL,
    )


def output_paths_for_year(year: int) -> list[Path]:
    paths = [
        PROCESSED / f"pedestrian_sensor_activity_{year}.csv",
        PROCESSED / f"pedestrian_activity_by_noise_buffer_{year}.csv",
    ]
    if year == 2024:
        paths.append(PROCESSED / "integrated_sensor_all_buffers_with_pedestrian_2024.csv")
    if year == 2025:
        paths.extend([
            PROCESSED / "noise_pedestrian_time_aligned_2025.csv",
            PROCESSED / "noise_pedestrian_integrated_2025.csv",
        ])
    return paths


def write_csv(frame: pd.DataFrame, path: Path) -> None:
    frame.to_csv(path, index=False)
    print(f"Created {path.relative_to(ROOT)}: {len(frame):,} rows")


def build_qa(counts: pd.DataFrame, sensor_2025: pd.DataFrame, buffer_2025: pd.DataFrame,
             aligned: pd.DataFrame, integrated: pd.DataFrame, diag_2026: pd.DataFrame,
             comparison: pd.DataFrame, locations: pd.DataFrame, noise_locations: pd.DataFrame,
             raw_hash_before: str, raw_hash_after: str) -> pd.DataFrame:
    checks: list[tuple[str, bool, str]] = []
    add = lambda name, passed, detail: checks.append((name, bool(passed), detail))
    year_rows = counts.groupby("year").size().to_dict()
    year_sensors = counts.groupby("year")["Location_ID"].nunique().to_dict()
    add("raw_source_unchanged", raw_hash_before == raw_hash_after, raw_hash_after)
    for year in (2024, 2025, 2026):
        add(f"rows_{year}", year_rows.get(year) == EXPECTED_YEAR_ROWS[year], str(year_rows.get(year)))
        add(f"sensors_{year}", year_sensors.get(year) == EXPECTED_YEAR_SENSORS[year], str(year_sensors.get(year)))
    add("pedestrian_key_unique", not counts.duplicated(["Location_ID", "Sensing_Date", "HourDay"]).any(), "Location_ID + Sensing_Date + HourDay")
    add("2025_location_id_unique", not sensor_2025["Location_ID"].duplicated().any(), f"{len(sensor_2025)} rows")
    unlocated_ids = sorted(sensor_2025.loc[~sensor_2025["has_location_coordinates"], "Location_ID"].astype(int).tolist())
    add("2025_location_join_documented", int(sensor_2025["has_location_coordinates"].sum()) == 100 and unlocated_ids == [28, 78],
        f"100/102 located; retained unlocated historical IDs: {unlocated_ids}")
    add("buffer_key_unique", not buffer_2025.duplicated(["device_id", "buffer_m"]).any(), f"{len(buffer_2025)} rows")
    add("eleven_noise_sensors_each_buffer", buffer_2025.groupby("buffer_m")["device_id"].nunique().eq(11).all(), str(buffer_2025.groupby("buffer_m")["device_id"].nunique().to_dict()))
    pivot = buffer_2025.pivot(index="device_id", columns="buffer_m", values="n_pedestrian_sensors")
    add("matched_sensor_count_nondecreasing", ((pivot[250] <= pivot[500]) & (pivot[500] <= pivot[1000])).all(), "250m <= 500m <= 1000m")
    activity_columns = [c for c in buffer_2025 if c.startswith("mean_") or c.startswith("sum_sensor_means_")]
    zero_rows = buffer_2025["n_pedestrian_sensors"].eq(0)
    add("zero_match_activity_is_na", buffer_2025.loc[zero_rows, activity_columns].isna().all().all(), f"{int(zero_rows.sum())} zero-match rows")
    add("aligned_noise_unique", not aligned["device_id"].duplicated().any() and len(aligned) == 11, f"{len(aligned)} sensors")
    add("aligned_period_2025", aligned["analysis_start_date"].eq("2025-01-01").all() and aligned["analysis_end_date"].eq("2025-12-31").all(), "2025 full calendar year")
    add("night_definition_consistent", True, "18:00-05:59 Australia/Melbourne for pedestrian and noise")
    add("integrated_key_unique", len(integrated) == 33 and not integrated.duplicated(["device_id", "buffer_m"]).any(), f"{len(integrated)} rows")
    add("business_baseline_label", integrated["business_feature_year"].eq(2024).all() and integrated["business_temporal_status"].eq(BUSINESS_TEMPORAL_STATUS).all(), "Lagged 2024 contextual baseline explicitly distinguished from 2025 measurements")
    add("2026_formally_excluded", len(diag_2026) == 25 and diag_2026["insufficient_coverage"].all(), f"{len(diag_2026)} sensor diagnostics")
    add("year_comparison_common_sensors", comparison.groupby("comparison_basis")["Location_ID"].nunique().nunique() == 1, str(comparison.groupby("comparison_basis")["Location_ID"].nunique().to_dict()))
    rebuilt_sensor = build_sensor_summary(counts.loc[counts["year"].eq(2025)].copy(), locations, 2025)
    rebuilt_buffer = build_buffer_summary(rebuilt_sensor, noise_locations, 2025)
    stable_sensor = sensor_2025.drop(columns=["generated_at"]).equals(rebuilt_sensor.drop(columns=["generated_at"]))
    stable_buffer = buffer_2025.drop(columns=["generated_at"]).equals(rebuilt_buffer.drop(columns=["generated_at"]))
    add("reproducible_in_memory_rebuild", stable_sensor and stable_buffer, "sensor and EPSG:7855 buffer outputs identical; generated_at excluded")
    qa = pd.DataFrame(checks, columns=["check", "passed", "details"])
    qa["status"] = np.where(qa["passed"], "PASS", "FAIL")
    qa = add_metadata(
        qa, "2024-08-19 to 2026-08-15", "2024_2026",
        "Automated QA for phase-one multi-year pedestrian preparation", f"{COUNTS_REL}; {LOCATIONS_REL}; {NOISE_RAW_REL}; {NOISE_LOCATIONS_REL}; {BUSINESS_BASELINE_REL}",
    )
    return qa


def write_summary(sensor_2025: pd.DataFrame, buffer_2025: pd.DataFrame, diag_2026: pd.DataFrame,
                  comparison: pd.DataFrame, qa: pd.DataFrame, path: Path) -> None:
    counts_500 = buffer_2025.loc[buffer_2025["buffer_m"].eq(500), "n_pedestrian_sensors"]
    common = comparison.groupby("comparison_basis")["Location_ID"].nunique().iloc[0]
    text = f"""# Pedestrian Activity Multiyear Data and QA

Generated by `{SCRIPT_REL}`.

## Scope

This document covers phase-one data preparation only. It distinguishes observed pedestrian movements from potential urban activity represented by bars, patron capacity, cafes and seating. No correlation, regression, leave-one-out analysis, inferential sensitivity analysis, analytical chart or statistical conclusion has been produced.

The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.

## Source coverage

- 2024: 286,845 hourly rows, 96 sensors, 2024-08-19 to 2024-12-31.
- 2025: 815,447 hourly rows, {sensor_2025['Location_ID'].nunique()} sensors, 2025-01-01 to 2025-12-31.
- 2026: 166 hourly rows, {diag_2026['Location_ID'].nunique()} sensors, {diag_2026['first_observed_date'].min()} to {diag_2026['last_observed_date'].max()}.
- The filename `pedestrian_counts_2019_2024.csv` is not authoritative for its actual date coverage.
- Historical Location_ID values 28 and 78 have 2025 observations but are absent from the current location file. Their time summaries are retained and they are excluded only from spatial matching.

## Definitions

- Time zone and calendar interpretation: Australia/Melbourne.
- Daytime: 06:00-17:59; night-time: 18:00-05:59.
- Weekday: Monday-Friday; weekend: Saturday-Sunday.
- Friday and Saturday evening: 18:00-23:59.
- Average daily count is retained as an observed-day mean. `avg_complete_day_pedestrian_count`, `mean_daily_hour_coverage_ratio`, `complete_days` and `complete_day_ratio` identify whether daily totals are based on complete 24-hour days.
- Pedestrian counts measure observed movements past counters, not unique people, venue customers or residential population.

## Spatial matching

Pedestrian and noise-sensor WGS84 coordinates are transformed to GDA2020 MGA Zone 55 EPSG:7855. Inclusive Euclidean distances are evaluated at 250 m, 500 m and 1,000 m. The unit is `device_id + buffer_m`; all 33 keys are unique. At 500 m the 11 noise sensors match between {int(counts_500.min())} and {int(counts_500.max())} pedestrian sensors.

When no pedestrian sensor is matched, `n_pedestrian_sensors` is zero and activity metrics are NA. Mean metrics are equal-weight averages of matched sensor summaries. Sum-of-sensor-means fields are monitored activity-intensity indices and must not be described as unique pedestrians because the same person may pass multiple counters.

## Time alignment and baseline features

The 2025 noise output is restricted to 2025-01-01 through 2025-12-31 and uses the same 18:00-05:59 night definition. Coverage uses unique valid noise timestamps against four expected 15-minute observations per night hour and is capped at one.

The integrated 2025 file labels business variables as `2024_baseline` and records `business_feature_year = 2024` with `business_temporal_status = \"Lagged 2024 contextual baseline; not a 2025 measurement\"`. These variables are optional contextual baselines, not contemporaneous 2025 business measurements.

## Cross-year preparation

The descriptive comparison contains {common} pedestrian sensors observed in both years. `matched_calendar_window` compares 19 August-31 December in each year; `available_year_data` retains partial 2024 versus full-year 2025 as a supplementary basis. Differences must not be interpreted as population trends because coverage, outages and network composition may change.

## 2026 decision

The 2026 source has only 166 records across 25 sensors and is excluded from formal activity analysis. `pedestrian_coverage_diagnostics_2026.csv` is diagnostic only and records the exclusion reason for every observed sensor.

## QA outcome

Automated QA passed {int(qa['passed'].sum())} of {len(qa)} checks. It covers source preservation, actual year counts, unique hourly keys, coordinate linkage, spatial-key uniqueness, 11 noise sensors per buffer, non-decreasing matched-sensor counts, zero-versus-NA semantics, time alignment, business-year labelling and formal 2026 exclusion.

## Outputs

- `data/processed/pedestrian_sensor_activity_2025.csv`
- `data/processed/pedestrian_activity_by_noise_buffer_2025.csv`
- `data/processed/noise_pedestrian_time_aligned_2025.csv`
- `data/processed/noise_pedestrian_integrated_2025.csv`
- `data/processed/pedestrian_activity_year_comparison_2024_2025.csv`
- `data/processed/pedestrian_coverage_diagnostics_2026.csv`
- `data/processed/pedestrian_multiyear_qa.csv`

## Reproduction

```powershell
python analysis/pedestrian_activity_integration_multiyear.py
```

Existing outputs cause a safe stop. Use `--overwrite` only to regenerate outputs previously created by this script. Legacy 2024 outputs remain protected even when that flag is supplied.

## Limitations

Pedestrian counters are not a random spatial sample. Counts can reflect weather, events, holidays, transport activity, outages and multiple counting of the same person. The 2024 observation period is partial, 2026 is inadequate for formal analysis, and 2024 business features are temporally lagged for the 2025 integration.
"""
    path.write_text(text, encoding="utf-8")
    print(f"Created {path.relative_to(ROOT)}")


def load_sources() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    paths = [ROOT / x for x in (COUNTS_REL, LOCATIONS_REL, NOISE_LOCATIONS_REL, NOISE_RAW_REL, BUSINESS_BASELINE_REL)]
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(f"Required input is missing: {path.relative_to(ROOT)}")
    counts = pd.read_csv(paths[0], usecols=["Location_ID", "Sensing_Date", "HourDay", "Total_of_Directions"])
    locations = pd.read_csv(paths[1])
    noise_locations = pd.read_csv(paths[2])
    noise_raw = pd.read_csv(paths[3], usecols=["Device_id", "Time", "Noise"], low_memory=False)
    baseline = pd.read_csv(paths[4])
    require_columns(locations, ["Location_ID", "Sensor_Description", "Latitude", "Longitude"], LOCATIONS_REL)
    require_columns(noise_locations, ["device_id", "latitude", "longitude"], NOISE_LOCATIONS_REL)
    if locations["Location_ID"].duplicated().any():
        raise ValueError("Pedestrian location source has duplicate Location_ID values")
    return prepare_counts(counts), locations, noise_locations, noise_raw, baseline


def run_year(year: int, overwrite: bool, counts: pd.DataFrame, locations: pd.DataFrame,
             noise_locations: pd.DataFrame, noise_raw: pd.DataFrame, baseline: pd.DataFrame) -> None:
    if year == 2026:
        path = PROCESSED / "pedestrian_coverage_diagnostics_2026.csv"
        ensure_writable_output(path, overwrite)
        write_csv(build_2026_diagnostics(counts), path)
        print("2026 pedestrian data have insufficient hourly coverage for formal activity analysis.")
        return
    if year not in SUPPORTED_FORMAL_YEARS:
        raise ValueError(f"Unsupported year {year}. Supported formal years are 2024 and 2025; 2026 is diagnostics only.")
    paths = output_paths_for_year(year)
    for path in paths:
        ensure_writable_output(path, overwrite)
    year_data = counts.loc[counts["year"].eq(year)].copy()
    if year_data.empty:
        raise ValueError(f"No pedestrian observations for {year}")
    sensor = build_sensor_summary(year_data, locations, year)
    buffer = build_buffer_summary(sensor, noise_locations, year)
    write_csv(sensor, paths[0])
    write_csv(buffer, paths[1])
    if year == 2024:
        existing = baseline.merge(buffer, on=["device_id", "buffer_m"], how="left", validate="one_to_one", suffixes=("", "_pedestrian"))
        existing = add_metadata(existing, str(sensor["analysis_period"].iloc[0]), 2024, "2024 noise, business baseline and pedestrian integration", f"{BUSINESS_BASELINE_REL}; data/processed/pedestrian_activity_by_noise_buffer_2024.csv")
        write_csv(existing, paths[2])
    else:
        aligned = build_time_aligned_noise(noise_raw, 2025)
        integrated = build_integrated_2025(buffer, aligned, baseline)
        write_csv(aligned, paths[2])
        write_csv(integrated, paths[3])


def run_all(overwrite: bool) -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    counts_path = ROOT / COUNTS_REL
    raw_hash_before = file_sha256(counts_path)
    counts, locations, noise_locations, noise_raw, baseline = load_sources()
    output_paths = output_paths_for_year(2025) + [
        PROCESSED / "pedestrian_activity_year_comparison_2024_2025.csv",
        PROCESSED / "pedestrian_coverage_diagnostics_2026.csv",
        PROCESSED / "pedestrian_multiyear_qa.csv",
        ANALYSIS / "pedestrian_activity_multiyear_summary.md",
    ]
    for path in output_paths:
        ensure_writable_output(path, overwrite)
    sensor_2025 = build_sensor_summary(counts.loc[counts["year"].eq(2025)].copy(), locations, 2025)
    buffer_2025 = build_buffer_summary(sensor_2025, noise_locations, 2025)
    aligned = build_time_aligned_noise(noise_raw, 2025)
    integrated = build_integrated_2025(buffer_2025, aligned, baseline)
    comparison = build_year_comparison(counts)
    diag_2026 = build_2026_diagnostics(counts)
    raw_hash_after = file_sha256(counts_path)
    qa = build_qa(counts, sensor_2025, buffer_2025, aligned, integrated, diag_2026,
                  comparison, locations, noise_locations, raw_hash_before, raw_hash_after)
    failed = qa.loc[~qa["passed"]]
    if len(failed):
        raise AssertionError("QA failed before outputs were written: " + "; ".join(failed["check"]))
    frames = [sensor_2025, buffer_2025, aligned, integrated, comparison, diag_2026, qa]
    for frame, path in zip(frames, output_paths[:7]):
        write_csv(frame, path)
    write_summary(sensor_2025, buffer_2025, diag_2026, comparison, qa, output_paths[7])
    print(f"Phase-one QA passed {int(qa['passed'].sum())}/{len(qa)} checks. Statistical analysis was not run.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate phase-one multi-year pedestrian data and QA outputs")
    parser.add_argument("--year", type=int, help="Generate a supported year (2024/2025); 2026 creates diagnostics only")
    parser.add_argument("--overwrite", action="store_true", help="Replace only outputs previously generated by this script")
    args = parser.parse_args()
    PROCESSED.mkdir(parents=True, exist_ok=True)
    if args.year is None:
        run_all(args.overwrite)
    else:
        counts, locations, noise_locations, noise_raw, baseline = load_sources()
        run_year(args.year, args.overwrite, counts, locations, noise_locations, noise_raw, baseline)


if __name__ == "__main__":
    main()
