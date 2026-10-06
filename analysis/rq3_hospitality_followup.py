"""Exploratory continuous follow-up to the frozen RQ3 hospitality screen.

The original median-based selection rule remains unchanged. This script uses
the same 11 monitored locations to describe the continuous rank association
between lagged 2024 hospitality counts and 2025 night-time recorded Noise.
The 500 m buffer is primary; 250 m and 1000 m are labelled sensitivities.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/processed/rq3_hospitality_screen_all_buffers.csv"
PROCESSED = ROOT / "data/processed"
FIGURES = ROOT / "figures"
ANALYSIS = ROOT / "analysis"
SCRIPT_REL = "analysis/rq3_hospitality_followup.py"
ASSOCIATION_PATH = PROCESSED / "rq3_hospitality_association_by_buffer.csv"
LOO_PATH = PROCESSED / "rq3_hospitality_association_leave_one_out.csv"
FIGURE_PATH = FIGURES / "final_rq3_hospitality_association_sensitivity.png"
REPORT_PATH = ANALYSIS / "rq3_hospitality_followup_summary.md"
OUTPUTS = [ASSOCIATION_PATH, LOO_PATH, FIGURE_PATH, REPORT_PATH]

OUTCOME = "nighttime_median_noise"
PREDICTOR = "hospitality_venues_2024"
BUFFERS = (250, 500, 1000)
PRIMARY_BUFFER = 500
PERMUTATIONS = 99_999
RANDOM_SEED = 5543


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def ensure_output(path: Path, overwrite: bool) -> None:
    if not path.exists():
        return
    if not overwrite:
        raise FileExistsError(
            f"Output exists: {path.relative_to(ROOT)}. Use --overwrite to regenerate this script's outputs."
        )
    if path.suffix == ".csv":
        check = pd.read_csv(path, nrows=3)
        if "generation_script" not in check or not check["generation_script"].eq(SCRIPT_REL).all():
            raise PermissionError(f"Refusing to overwrite foreign CSV: {path.relative_to(ROOT)}")
    elif path.suffix == ".md" and SCRIPT_REL not in path.read_text(encoding="utf-8"):
        raise PermissionError(f"Refusing to overwrite foreign report: {path.relative_to(ROOT)}")


def add_metadata(frame: pd.DataFrame, purpose: str) -> pd.DataFrame:
    return frame.assign(
        source_files="data/processed/rq3_hospitality_screen_all_buffers.csv",
        analysis_period="2025-01-01 to 2025-12-31",
        context_year=2024,
        output_purpose=purpose,
        analysis_status="exploratory follow-up after frozen median screen",
        generation_script=SCRIPT_REL,
        generated_at=timestamp(),
    )


def load_data() -> pd.DataFrame:
    required = ["device_id", "buffer_m", OUTCOME, PREDICTOR]
    data = (
        pd.read_csv(INPUT, usecols=required)
        .assign(
            buffer_m=lambda frame: pd.to_numeric(frame["buffer_m"], errors="raise").astype(int),
            nighttime_median_noise=lambda frame: pd.to_numeric(frame[OUTCOME], errors="raise"),
            hospitality_venues_2024=lambda frame: pd.to_numeric(frame[PREDICTOR], errors="raise"),
        )
        .dropna(subset=required)
        .sort_values(["buffer_m", "device_id"])
        .reset_index(drop=True)
    )
    counts = data.groupby("buffer_m")["device_id"].nunique().to_dict()
    if len(data) != 33 or counts != {250: 11, 500: 11, 1000: 11}:
        raise ValueError(f"Expected 11 unique eligible sites at each buffer; found {counts}")
    if data.duplicated(["device_id", "buffer_m"]).any():
        raise ValueError("Input contains duplicate device_id + buffer_m keys")
    if not np.isfinite(data[[OUTCOME, PREDICTOR]].to_numpy()).all():
        raise ValueError("RQ3 follow-up variables must be finite")
    return data


def permutation_spearman(x: np.ndarray, y: np.ndarray, seed: int) -> tuple[float, float]:
    x_rank = stats.rankdata(x)
    y_rank = stats.rankdata(y)
    x_standardised = (x_rank - x_rank.mean()) / np.sqrt(np.sum((x_rank - x_rank.mean()) ** 2))
    y_standardised = (y_rank - y_rank.mean()) / np.sqrt(np.sum((y_rank - y_rank.mean()) ** 2))
    observed = float(np.dot(x_standardised, y_standardised))
    rng = np.random.default_rng(seed)
    exceedances = 0
    remaining = PERMUTATIONS
    while remaining:
        batch_size = min(10_000, remaining)
        permuted = np.vstack([rng.permutation(y_standardised) for _ in range(batch_size)])
        permuted_rho = permuted @ x_standardised
        exceedances += int(np.sum(np.abs(permuted_rho) >= abs(observed) - 1e-15))
        remaining -= batch_size
    return observed, (exceedances + 1) / (PERMUTATIONS + 1)


def association_table(data: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for seed_offset, buffer_m in enumerate(BUFFERS):
        sample = data.loc[data["buffer_m"].eq(buffer_m), ["device_id", OUTCOME, PREDICTOR]]
        rho, permutation_p = permutation_spearman(
            sample[PREDICTOR].to_numpy(),
            sample[OUTCOME].to_numpy(),
            RANDOM_SEED + seed_offset,
        )
        asymptotic = stats.spearmanr(sample[PREDICTOR], sample[OUTCOME])
        rows.append(
            {
                "buffer_m": buffer_m,
                "specification_role": "primary" if buffer_m == PRIMARY_BUFFER else "buffer_sensitivity",
                "outcome": OUTCOME,
                "predictor": PREDICTOR,
                "n_sites": len(sample),
                "spearman_rho": rho,
                "spearman_asymptotic_p_value": asymptotic.pvalue,
                "spearman_permutation_p_value": permutation_p,
                "permutation_draws": PERMUTATIONS,
                "random_seed": RANDOM_SEED + seed_offset,
            }
        )
    result = (
        pd.DataFrame(rows)
        .sort_values("buffer_m")
        .reset_index(drop=True)
        .pipe(add_metadata, "Continuous hospitality-Noise rank association by spatial buffer")
    )
    if result["spearman_rho"].isna().any() or not result["n_sites"].eq(11).all():
        raise ValueError("Association output failed completeness checks")
    return result


def leave_one_out_table(data: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for buffer_m in BUFFERS:
        sample = data.loc[data["buffer_m"].eq(buffer_m), ["device_id", OUTCOME, PREDICTOR]]
        for omitted_device_id in sample["device_id"]:
            retained = sample.loc[~sample["device_id"].eq(omitted_device_id)]
            rows.append(
                {
                    "buffer_m": buffer_m,
                    "specification_role": "primary" if buffer_m == PRIMARY_BUFFER else "buffer_sensitivity",
                    "omitted_device_id": omitted_device_id,
                    "n_after_omission": len(retained),
                    "spearman_rho": stats.spearmanr(retained[PREDICTOR], retained[OUTCOME]).statistic,
                }
            )
    result = (
        pd.DataFrame(rows)
        .sort_values(["buffer_m", "omitted_device_id"])
        .reset_index(drop=True)
        .pipe(add_metadata, "Leave-one-site-out sensitivity of hospitality-Noise Spearman association")
    )
    if len(result) != 33 or not result["n_after_omission"].eq(10).all():
        raise ValueError("Leave-one-site-out output requires 11 omissions per buffer and n=10 per estimate")
    if result["spearman_rho"].isna().any():
        raise ValueError("Leave-one-site-out output contains missing correlations")
    return result


def make_figure(associations: pd.DataFrame, leave_one_out: pd.DataFrame) -> None:
    sensitivity = (
        leave_one_out.groupby("buffer_m", as_index=False)
        .agg(
            loo_min_rho=("spearman_rho", "min"),
            loo_max_rho=("spearman_rho", "max"),
        )
        .merge(
            associations[["buffer_m", "spearman_rho", "spearman_permutation_p_value"]],
            on="buffer_m",
            how="left",
            validate="one_to_one",
        )
        .sort_values("buffer_m")
        .reset_index(drop=True)
    )
    x_positions = np.arange(len(sensitivity))
    y = sensitivity["spearman_rho"].to_numpy()
    yerr = np.vstack(
        [
            y - sensitivity["loo_min_rho"].to_numpy(),
            sensitivity["loo_max_rho"].to_numpy() - y,
        ]
    )
    colours = ["#9CA3AF", "#2166AC", "#9CA3AF"]

    figure, axis = plt.subplots(figsize=(9.5, 6.2), constrained_layout=True)
    axis.axhline(0, color="#6B7280", linewidth=1.0, linestyle="--")
    for index, row in sensitivity.iterrows():
        axis.errorbar(
            x_positions[index],
            row["spearman_rho"],
            yerr=np.array(
                [
                    [row["spearman_rho"] - row["loo_min_rho"]],
                    [row["loo_max_rho"] - row["spearman_rho"]],
                ]
            ),
            fmt="o",
            markersize=9 if row["buffer_m"] == PRIMARY_BUFFER else 7,
            color=colours[index],
            ecolor=colours[index],
            elinewidth=2.0,
            capsize=5,
            zorder=3,
        )
        axis.annotate(
            f"rho = {row['spearman_rho']:.2f}\np = {row['spearman_permutation_p_value']:.3f}",
            (x_positions[index], row["loo_max_rho"]),
            xytext=(0, 10),
            textcoords="offset points",
            ha="center",
            fontsize=9,
            color="#111827",
        )

    axis.set_xticks(x_positions, [f"{value:,} m" for value in sensitivity["buffer_m"]])
    axis.set_ylim(min(-0.05, float((y - yerr[0]).min()) - 0.08), 1.02)
    axis.set_title(
        "RQ3 exploratory follow-up: hospitality presence and night-time recorded Noise",
        loc="left",
        weight="bold",
    )
    axis.set_xlabel("Descriptive buffer distance")
    axis.set_ylabel("Spearman rank correlation")
    axis.grid(axis="y", color="#E5E7EB", linewidth=0.8)
    axis.spines[["top", "right"]].set_visible(False)
    axis.text(
        0,
        -0.18,
        "Points use all 11 monitored locations. Bars show leave-one-site-out ranges, not confidence intervals.\n"
        "Two-sided p-values use 99,999 permutations. 2024 venue counts are a lagged context for 2025 night-time Noise.",
        transform=axis.transAxes,
        fontsize=9,
        color="#4B5563",
    )
    figure.savefig(FIGURE_PATH, dpi=220, bbox_inches="tight")
    plt.close(figure)


def write_report(associations: pd.DataFrame, leave_one_out: pd.DataFrame) -> None:
    primary = associations.loc[associations["buffer_m"].eq(PRIMARY_BUFFER)].iloc[0]
    ranges = (
        leave_one_out.groupby("buffer_m")["spearman_rho"]
        .agg(["min", "max"])
        .rename_axis("buffer_m")
    )
    buffer_lines = "\n".join(
        f"- {int(row.buffer_m):,} m: rho = {row.spearman_rho:.3f}; "
        f"permutation p = {row.spearman_permutation_p_value:.3f}; "
        f"leave-one-site-out range = {ranges.loc[row.buffer_m, 'min']:.3f} to {ranges.loc[row.buffer_m, 'max']:.3f}"
        for row in associations.itertuples(index=False)
    )
    report = f"""# RQ3 Hospitality Follow-up Summary

This report is generated by `{SCRIPT_REL}`.

## Analysis status

This is an exploratory continuous follow-up conducted after the frozen median-based RQ3 screen returned no candidate at the primary 500 m buffer. It does not replace or alter that screen.

## Result

At 500 m, the Spearman association between lagged 2024 hospitality venue count and 2025 night-time recorded Noise is {primary.spearman_rho:.3f} (two-sided {PERMUTATIONS:,}-draw permutation p = {primary.spearman_permutation_p_value:.3f}; n = {int(primary.n_sites)}). The leave-one-site-out range is {ranges.loc[PRIMARY_BUFFER, 'min']:.3f} to {ranges.loc[PRIMARY_BUFFER, 'max']:.3f}.

Buffer results are:

{buffer_lines}

The positive direction is retained across all three buffers, while the magnitude is weaker at 1,000 m. These descriptive results apply only to the monitored locations. They do not show that hospitality venues caused higher recorded values, and the 2024 venue counts are a lagged context rather than a contemporaneous 2025 exposure measure.

## Generated outputs

- `data/processed/rq3_hospitality_association_by_buffer.csv`
- `data/processed/rq3_hospitality_association_leave_one_out.csv`
- `figures/final_rq3_hospitality_association_sensitivity.png`
"""
    REPORT_PATH.write_text(report, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    for output in OUTPUTS:
        ensure_output(output, args.overwrite)
    PROCESSED.mkdir(parents=True, exist_ok=True)
    FIGURES.mkdir(parents=True, exist_ok=True)

    data = load_data()
    associations = association_table(data)
    leave_one_out = leave_one_out_table(data)
    associations.to_csv(ASSOCIATION_PATH, index=False)
    leave_one_out.to_csv(LOO_PATH, index=False)
    make_figure(associations, leave_one_out)
    write_report(associations, leave_one_out)

    for output in OUTPUTS:
        print(f"Created {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
