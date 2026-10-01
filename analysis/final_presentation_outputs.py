"""Create the frozen sensor-level, spatial, and RQ3 presentation outputs."""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
from matplotlib.patches import Circle, Patch
import numpy as np
import pandas as pd
from pyproj import Transformer


ROOT = Path(__file__).resolve().parents[1]
RAW_NOISE = ROOT / "data/raw/microclimate_sensors.csv"
SENSOR_COVERAGE = ROOT / "data/processed/sensor_coverage_summary.csv"
SENSOR_LOCATIONS = ROOT / "data/processed/noise_sensor_locations.csv"
SENSOR_DAYS = ROOT / "data/processed/noise_sensor_day.csv"
PEDESTRIAN_SENSORS = ROOT / "data/processed/pedestrian_sensor_activity_2025.csv"
INTEGRATED_2025 = ROOT / "data/processed/noise_pedestrian_integrated_2025.csv"
BOUNDARY = ROOT / "data/reference/melbourne_municipal_boundary_coordinates.csv"
PROCESSED = ROOT / "data/processed"
FIGURES = ROOT / "figures"
REPORT = ROOT / "analysis/final_presentation_outputs_summary.md"

SENSOR_HOUR_PATH = PROCESSED / "final_sensor_hour_profiles.csv"
SENSOR_SUMMARY_PATH = PROCESSED / "final_sensor_site_summary.csv"
RQ3_TABLE_PATH = PROCESSED / "rq3_hospitality_screen_all_buffers.csv"
RQ3_SUMMARY_PATH = PROCESSED / "rq3_hospitality_screen_summary.csv"
HEATMAP_PATH = FIGURES / "final_sensor_hour_heatmap.png"
PROFILES_PATH = FIGURES / "final_sensor_hour_profiles.png"
MAP_PATH = FIGURES / "final_noise_pedestrian_context_map_500m.png"
RQ3_PATH = FIGURES / "final_rq3_hospitality_screen_500m.png"

OUTPUTS = (
    SENSOR_HOUR_PATH,
    SENSOR_SUMMARY_PATH,
    RQ3_TABLE_PATH,
    RQ3_SUMMARY_PATH,
    HEATMAP_PATH,
    PROFILES_PATH,
    MAP_PATH,
    RQ3_PATH,
    REPORT,
)


def ensure_outputs(overwrite: bool) -> None:
    existing = [path for path in OUTPUTS if path.exists()]
    if existing and not overwrite:
        names = ", ".join(str(path.relative_to(ROOT)) for path in existing)
        raise FileExistsError(f"Outputs already exist: {names}. Re-run with --overwrite.")
    PROCESSED.mkdir(parents=True, exist_ok=True)
    FIGURES.mkdir(parents=True, exist_ok=True)


def short_sensor_id(series: pd.Series) -> pd.Series:
    return series.str.replace("ICTMicroclimate-", "", regex=False)


def sensor_outputs() -> tuple[pd.DataFrame, pd.DataFrame]:
    raw = (
        pd.read_csv(RAW_NOISE, usecols=["Device_id", "Time", "Noise"], low_memory=False)
        .assign(
            Noise=lambda frame: pd.to_numeric(frame["Noise"], errors="coerce"),
            timestamp_utc=lambda frame: pd.to_datetime(
                frame["Time"], format="mixed", errors="coerce", utc=True
            ),
        )
        .assign(
            hour=lambda frame: frame["timestamp_utc"]
            .dt.tz_convert("Australia/Melbourne")
            .dt.hour
        )
        .dropna(subset=["Noise", "hour"])
        .assign(hour=lambda frame: frame["hour"].astype(int))
    )
    usable_ids = sorted(raw["Device_id"].unique())
    complete_index = pd.MultiIndex.from_product(
        [usable_ids, range(24)], names=["device_id", "hour"]
    )
    profiles = (
        raw.groupby(["Device_id", "hour"], as_index=True)
        .agg(median_noise=("Noise", "median"), valid_observations=("Noise", "size"))
        .rename_axis(index=["device_id", "hour"])
        .reindex(complete_index)
        .reset_index()
    )

    coverage = (
        pd.read_csv(SENSOR_COVERAGE)
        .rename(
            columns={
                "Device_id": "device_id",
                "SensorLocation": "sensor_location",
                "valid_noise": "valid_observations",
                "median_noise": "overall_median_noise",
            }
        )
        .query("valid_observations > 0")
    )
    active_days = (
        pd.read_csv(SENSOR_DAYS, usecols=["device_id", "date", "n_valid_noise"])
        .query("n_valid_noise > 0")
        .groupby("device_id", as_index=False)
        .agg(active_days=("date", "nunique"))
    )
    site_summary = (
        coverage.merge(active_days, on="device_id", how="left", validate="one_to_one")
        .loc[
            :,
            [
                "device_id",
                "sensor_location",
                "latitude",
                "longitude",
                "overall_median_noise",
                "valid_observations",
                "active_days",
                "first_observation",
                "last_observation",
            ],
        ]
        .sort_values("device_id")
        .reset_index(drop=True)
    )
    if len(usable_ids) != 11 or len(profiles) != 264 or len(site_summary) != 11:
        raise ValueError("Expected 11 usable sensors and a complete 11 x 24 profile grid")
    return profiles, site_summary


def make_heatmap(profiles: pd.DataFrame) -> None:
    matrix = profiles.pivot(index="device_id", columns="hour", values="median_noise")
    colours = LinearSegmentedColormap.from_list(
        "noise_blue_orange", ["#2C7BB6", "#ABD9E9", "#FFFFBF", "#FDAE61", "#D7191C"]
    )
    colours.set_bad("#D1D5DB")
    figure, axis = plt.subplots(figsize=(12.0, 6.4), constrained_layout=True)
    image = axis.imshow(np.ma.masked_invalid(matrix.to_numpy()), aspect="auto", cmap=colours)
    axis.set_title("Median recorded Noise by monitored sensor and local hour", loc="left", weight="bold")
    axis.set_xlabel("Hour of day (Australia/Melbourne)")
    axis.set_ylabel("Monitored sensor")
    axis.set_xticks(range(24), [f"{hour:02d}" for hour in range(24)])
    axis.set_yticks(range(len(matrix.index)), short_sensor_id(matrix.index.to_series()))
    axis.tick_params(length=0)
    colour_bar = figure.colorbar(image, ax=axis, pad=0.015)
    colour_bar.set_label("Median recorded Noise (dataset units)")
    axis.text(
        0,
        -0.15,
        "Each cell is the median of all finite observations for one sensor-hour; grey denotes missing.",
        transform=axis.transAxes,
        color="#4B5563",
        fontsize=9,
    )
    figure.savefig(HEATMAP_PATH, dpi=200, bbox_inches="tight")
    plt.close(figure)


def make_profiles(profiles: pd.DataFrame) -> None:
    sensor_ids = sorted(profiles["device_id"].unique())
    y_limits = profiles["median_noise"].agg(["min", "max"]).to_numpy(dtype=float)
    padding = max((y_limits[1] - y_limits[0]) * 0.06, 1.0)
    figure, axes = plt.subplots(3, 4, figsize=(14.0, 9.0), sharex=True, sharey=True, constrained_layout=True)
    for axis, device_id in zip(axes.flat, sensor_ids, strict=False):
        subset = profiles.loc[profiles["device_id"].eq(device_id)]
        axis.plot(subset["hour"], subset["median_noise"], color="#2166AC", linewidth=2.0)
        axis.scatter(subset["hour"], subset["median_noise"], color="#2166AC", s=11)
        axis.set_title(f"Sensor {device_id[-2:]}", loc="left", fontsize=10, weight="bold")
        axis.set_xlim(0, 23)
        axis.set_ylim(y_limits[0] - padding, y_limits[1] + padding)
        axis.set_xticks([0, 6, 12, 18, 23])
        axis.grid(axis="y", color="#E5E7EB", linewidth=0.8)
        axis.spines[["top", "right"]].set_visible(False)
    for axis in axes.flat[len(sensor_ids) :]:
        axis.set_visible(False)
    figure.suptitle("Sensor-specific 24-hour recorded Noise profiles", x=0.01, ha="left", weight="bold")
    figure.supxlabel("Hour of day (Australia/Melbourne)")
    figure.supylabel("Median recorded Noise (dataset units)")
    figure.text(
        0.01,
        -0.015,
        "All panels use identical axes. Each point is the median of finite observations for that sensor-hour.",
        color="#4B5563",
        fontsize=9,
    )
    figure.savefig(PROFILES_PATH, dpi=200, bbox_inches="tight")
    plt.close(figure)


def project_coordinates(frame: pd.DataFrame) -> pd.DataFrame:
    transformer = Transformer.from_crs("EPSG:4326", "EPSG:7855", always_xy=True)
    east, north = transformer.transform(
        frame["longitude"].to_numpy(dtype=float), frame["latitude"].to_numpy(dtype=float)
    )
    return frame.assign(easting=east, northing=north)


def make_context_map() -> tuple[int, int]:
    noise = (
        pd.read_csv(SENSOR_LOCATIONS)
        .query("n_valid_noise > 0")
        .loc[:, ["device_id", "latitude", "longitude"]]
        .pipe(project_coordinates)
        .sort_values("device_id")
    )
    pedestrian = (
        pd.read_csv(PEDESTRIAN_SENSORS)
        .query("has_location_coordinates == True")
        .rename(columns={"Latitude": "latitude", "Longitude": "longitude"})
        .loc[:, ["Location_ID", "Sensor_Description", "latitude", "longitude"]]
        .dropna(subset=["latitude", "longitude"])
        .pipe(project_coordinates)
    )
    distance_squared = (
        (pedestrian["easting"].to_numpy()[:, None] - noise["easting"].to_numpy()[None, :]) ** 2
        + (pedestrian["northing"].to_numpy()[:, None] - noise["northing"].to_numpy()[None, :]) ** 2
    )
    pedestrian = pedestrian.assign(inside_primary_buffer=distance_squared.min(axis=1) <= 500**2)
    map_padding = 1_250
    x_limits = (noise["easting"].min() - map_padding, noise["easting"].max() + map_padding)
    y_limits = (noise["northing"].min() - map_padding, noise["northing"].max() + map_padding)
    pedestrian_display = pedestrian.loc[
        pedestrian["easting"].between(*x_limits) & pedestrian["northing"].between(*y_limits)
    ]

    figure, axis = plt.subplots(figsize=(10.5, 10.0), constrained_layout=True)
    if BOUNDARY.exists():
        boundary = pd.read_csv(BOUNDARY)
        for _, ring in boundary.groupby("ring_id", sort=False):
            projected_ring = project_coordinates(ring)
            axis.fill(
                projected_ring["easting"],
                projected_ring["northing"],
                facecolor="#F3F4F6",
                edgecolor="#9CA3AF",
                linewidth=0.7,
                zorder=0,
            )
    for row in noise.itertuples(index=False):
        axis.add_patch(
            Circle(
                (row.easting, row.northing),
                radius=500,
                facecolor="#60A5FA",
                edgecolor="#2563EB",
                alpha=0.10,
                linewidth=1.0,
                zorder=1,
            )
        )
    outside = pedestrian_display.loc[~pedestrian_display["inside_primary_buffer"]]
    inside = pedestrian_display.loc[pedestrian_display["inside_primary_buffer"]]
    axis.scatter(outside["easting"], outside["northing"], s=13, color="#9CA3AF", alpha=0.75, zorder=2)
    axis.scatter(inside["easting"], inside["northing"], s=22, color="#E67E22", alpha=0.95, zorder=3)
    axis.scatter(
        noise["easting"], noise["northing"], marker="^", s=72, color="#0B3C5D", edgecolor="white", linewidth=0.7, zorder=4
    )
    label_offsets = {"03": (4, 8), "08": (4, 8), "10": (-19, 7), "11": (6, 7)}
    for row in noise.itertuples(index=False):
        label = row.device_id[-2:]
        axis.annotate(
            label,
            (row.easting, row.northing),
            xytext=label_offsets.get(label, (5, 5)),
            textcoords="offset points",
            fontsize=8,
            weight="bold",
        )
    axis.set_title("Noise sensors, 500 m buffers, and 2025 pedestrian counters", loc="left", weight="bold")
    axis.set_xlabel("Easting (metres, GDA2020 / MGA zone 55)")
    axis.set_ylabel("Northing (metres, GDA2020 / MGA zone 55)")
    axis.set_xlim(*x_limits)
    axis.set_ylim(*y_limits)
    axis.set_aspect("equal", adjustable="box")
    axis.grid(color="#E5E7EB", linewidth=0.6)
    axis.legend(
        handles=[
            plt.Line2D([], [], marker="^", linestyle="", markersize=8, markerfacecolor="#0B3C5D", markeredgecolor="white", label="Usable Noise sensor"),
            Patch(facecolor="#60A5FA", edgecolor="#2563EB", alpha=0.20, label="500 m descriptive buffer"),
            plt.Line2D([], [], marker="o", linestyle="", color="#E67E22", label="2025 counter inside a buffer"),
            plt.Line2D([], [], marker="o", linestyle="", color="#9CA3AF", label="Other eligible 2025 counter"),
        ],
        loc="lower left",
        frameon=True,
    )
    axis.text(
        0,
        -0.10,
        "Buffers are proximity summaries, not neighbourhood boundaries or causal exposure zones.",
        transform=axis.transAxes,
        color="#4B5563",
        fontsize=9,
    )
    figure.savefig(MAP_PATH, dpi=200, bbox_inches="tight")
    plt.close(figure)
    return len(pedestrian_display), int(inside.shape[0])


def rq3_outputs() -> tuple[pd.DataFrame, pd.DataFrame]:
    base = (
        pd.read_csv(INTEGRATED_2025)
        .loc[
            :,
            [
                "device_id",
                "buffer_m",
                "nighttime_median_noise",
                "n_bars_2024_baseline",
                "n_cafes_2024_baseline",
            ],
        ]
        .dropna(
            subset=[
                "nighttime_median_noise",
                "n_bars_2024_baseline",
                "n_cafes_2024_baseline",
            ]
        )
        .assign(
            hospitality_venues_2024=lambda frame: (
                frame["n_bars_2024_baseline"] + frame["n_cafes_2024_baseline"]
            )
        )
    )
    thresholds = (
        base.groupby("buffer_m", as_index=False)
        .agg(
            noise_median_threshold=("nighttime_median_noise", "median"),
            hospitality_median_threshold=("hospitality_venues_2024", "median"),
        )
    )
    screen = (
        base.merge(thresholds, on="buffer_m", how="left", validate="many_to_one")
        .assign(
            below_noise_median=lambda frame: frame["nighttime_median_noise"].lt(frame["noise_median_threshold"]),
            above_hospitality_median=lambda frame: frame["hospitality_venues_2024"].gt(frame["hospitality_median_threshold"]),
        )
        .assign(
            descriptive_candidate=lambda frame: frame["below_noise_median"] & frame["above_hospitality_median"]
        )
        .sort_values(["buffer_m", "device_id"])
        .reset_index(drop=True)
    )
    summary = (
        screen.groupby("buffer_m", as_index=False)
        .agg(
            eligible_sites=("device_id", "size"),
            noise_median_threshold=("noise_median_threshold", "first"),
            hospitality_median_threshold=("hospitality_median_threshold", "first"),
            candidate_sites=("descriptive_candidate", "sum"),
            candidate_device_ids=(
                "device_id",
                lambda ids: "; ".join(ids[screen.loc[ids.index, "descriptive_candidate"]]),
            ),
        )
        .sort_values("buffer_m")
        .reset_index(drop=True)
    )
    if len(screen) != 33 or summary.set_index("buffer_m")["eligible_sites"].to_dict() != {250: 11, 500: 11, 1000: 11}:
        raise ValueError("RQ3 requires 11 eligible sensors at each of the three buffers")
    return screen, summary


def make_rq3_figure(screen: pd.DataFrame) -> None:
    primary = screen.loc[screen["buffer_m"].eq(500)].copy()
    noise_threshold = float(primary["noise_median_threshold"].iloc[0])
    hospitality_threshold = float(primary["hospitality_median_threshold"].iloc[0])
    x_max = float(primary["hospitality_venues_2024"].max()) * 1.07
    y_min = float(primary["nighttime_median_noise"].min()) - 2.0
    y_max = float(primary["nighttime_median_noise"].max()) + 2.0

    figure, axis = plt.subplots(figsize=(10.5, 7.0), constrained_layout=True)
    axis.axvspan(hospitality_threshold, x_max, ymin=0, ymax=(noise_threshold - y_min) / (y_max - y_min), color="#D1FAE5", alpha=0.65, zorder=0)
    axis.axvline(hospitality_threshold, color="#6B7280", linestyle="--", linewidth=1.2)
    axis.axhline(noise_threshold, color="#6B7280", linestyle="--", linewidth=1.2)
    colours = np.where(primary["descriptive_candidate"], "#047857", "#2166AC")
    axis.scatter(primary["hospitality_venues_2024"], primary["nighttime_median_noise"], s=58, c=colours, edgecolor="white", linewidth=0.8, zorder=2)
    offsets = {"01": (6, -13), "02": (6, 5), "03": (6, 5), "04": (6, 5), "05": (6, -13), "06": (6, 5), "07": (6, -13), "08": (6, 5), "09": (6, 5), "10": (6, 5), "11": (6, 5)}
    for row in primary.itertuples(index=False):
        label = row.device_id[-2:]
        axis.annotate(label, (row.hospitality_venues_2024, row.nighttime_median_noise), xytext=offsets[label], textcoords="offset points", fontsize=9, weight="bold")
    axis.set_xlim(0, x_max)
    axis.set_ylim(y_min, y_max)
    axis.set_title("RQ3 screen: lower night-time recorded Noise and stronger hospitality presence", loc="left", weight="bold")
    axis.set_xlabel("Bars and cafes/restaurants within 500 m (2024 source records)")
    axis.set_ylabel("2025 night-time median recorded Noise (dataset units)")
    axis.grid(color="#E5E7EB", linewidth=0.7)
    axis.text(hospitality_threshold + 10, y_min + 0.7, "Fixed candidate quadrant", color="#047857", fontsize=9, weight="bold")
    axis.text(
        0,
        -0.15,
        f"Strict thresholds: Noise < {noise_threshold:.1f} and hospitality venues > {hospitality_threshold:.0f}. No 500 m site meets both criteria.",
        transform=axis.transAxes,
        color="#4B5563",
        fontsize=9,
    )
    figure.savefig(RQ3_PATH, dpi=200, bbox_inches="tight")
    plt.close(figure)


def write_report(site_summary: pd.DataFrame, pedestrian_total: int, pedestrian_inside: int, rq3_summary: pd.DataFrame) -> None:
    primary = rq3_summary.loc[rq3_summary["buffer_m"].eq(500)].iloc[0]
    sensitivity_lines = "\n".join(
        f"- {int(row.buffer_m):,} m: {int(row.candidate_sites)} candidate(s)"
        + (f" ({row.candidate_device_ids})" if row.candidate_device_ids else "")
        for row in rq3_summary.itertuples(index=False)
    )
    report = f"""# Final Presentation Output Summary

## Sensor-level outputs

The heatmap and small-multiple profiles cover {len(site_summary)} usable Noise sensors. All panels use a common scale, and all summaries retain finite recorded zero values. The overall site medians range from {site_summary['overall_median_noise'].min():.1f} to {site_summary['overall_median_noise'].max():.1f} dataset units.

Observed site differences cannot be separated from sensor calibration, mounting, placement, or local exposure differences with the available metadata.

## Spatial context map

The map contains {len(site_summary)} usable Noise sensors, labelled 500 m buffers, and {pedestrian_total} pedestrian counters with valid coordinates in the 2025 activity file. Of those counters, {pedestrian_inside} fall within at least one primary buffer. Buffers are descriptive proximity summaries, not neighbourhood boundaries or causal exposure zones.

## RQ3 hospitality screen

The primary 500 m screen contains {int(primary.eligible_sites)} eligible sites. Its strict thresholds are a 2025 night-time median recorded Noise value below {primary.noise_median_threshold:.1f} and a lagged 2024 hospitality venue count above {primary.hospitality_median_threshold:.0f}. No 500 m site meets both conditions. The thresholds were not changed after this result was observed.

Sensitivity counts using the identical rule are:

{sensitivity_lines}

This screen is a transparent descriptive prioritisation exercise. It is not a statistical test, a causal comparison, a measure of realised amenity access, or a residential recommendation.

## Generated outputs

- `data/processed/final_sensor_hour_profiles.csv`
- `data/processed/final_sensor_site_summary.csv`
- `data/processed/rq3_hospitality_screen_all_buffers.csv`
- `data/processed/rq3_hospitality_screen_summary.csv`
- `figures/final_sensor_hour_heatmap.png`
- `figures/final_sensor_hour_profiles.png`
- `figures/final_noise_pedestrian_context_map_500m.png`
- `figures/final_rq3_hospitality_screen_500m.png`
"""
    REPORT.write_text(report, encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    ensure_outputs(args.overwrite)

    profiles, site_summary = sensor_outputs()
    rq3_screen, rq3_summary = rq3_outputs()
    profiles.to_csv(SENSOR_HOUR_PATH, index=False)
    site_summary.to_csv(SENSOR_SUMMARY_PATH, index=False)
    rq3_screen.to_csv(RQ3_TABLE_PATH, index=False)
    rq3_summary.to_csv(RQ3_SUMMARY_PATH, index=False)
    make_heatmap(profiles)
    make_profiles(profiles)
    pedestrian_total, pedestrian_inside = make_context_map()
    make_rq3_figure(rq3_screen)
    write_report(site_summary, pedestrian_total, pedestrian_inside, rq3_summary)

    for output in OUTPUTS:
        print(f"Created {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
