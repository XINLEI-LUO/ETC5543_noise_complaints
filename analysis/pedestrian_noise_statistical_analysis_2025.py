"""Phase-two exploratory statistics for 2025 pedestrian activity and noise.

The 500 m buffer is primary. The 250 m and 1000 m models are sensitivity
specifications, never pooled as independent observations. Results are
descriptive/exploratory and do not support causal inference.
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
import statsmodels.api as sm


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "data/processed/noise_pedestrian_integrated_2025.csv"
PROCESSED = ROOT / "data/processed"
FIGURES = ROOT / "figures"
ANALYSIS = ROOT / "analysis"
SCRIPT_REL = "analysis/pedestrian_noise_statistical_analysis_2025.py"
CORRELATION_PATH = PROCESSED / "pedestrian_noise_correlations_2025.csv"
MODEL_PATH = PROCESSED / "pedestrian_noise_models_2025.csv"
LOO_PATH = PROCESSED / "pedestrian_noise_leave_one_out_2025.csv"
SCATTER_PATH = FIGURES / "pedestrian_nighttime_noise_500m_2025.png"
SENSITIVITY_PATH = FIGURES / "pedestrian_noise_buffer_sensitivity_2025.png"
REPORT_PATH = ANALYSIS / "pedestrian_noise_statistical_report_2025.md"
OUTPUTS = [CORRELATION_PATH, MODEL_PATH, LOO_PATH, SCATTER_PATH, SENSITIVITY_PATH, REPORT_PATH]
OUTCOME = "nighttime_median_noise"
PREDICTORS = {
    "pedestrian_mean": "mean_nighttime_avg_hourly_pedestrian_count",
    "pedestrian_intensity_sum": "sum_sensor_means_nighttime_avg_hourly_pedestrian_count",
}
PERMUTATIONS = 99_999
RANDOM_SEED = 5543


def timestamp() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def ensure_output(path: Path, overwrite: bool) -> None:
    if not path.exists():
        return
    if not overwrite:
        raise FileExistsError(f"Output exists: {path.relative_to(ROOT)}. Use --overwrite to regenerate this script's outputs.")
    if path.suffix == ".csv":
        check = pd.read_csv(path, nrows=3)
        if "generation_script" not in check or not check["generation_script"].eq(SCRIPT_REL).all():
            raise PermissionError(f"Refusing to overwrite foreign CSV: {path.relative_to(ROOT)}")
    elif path.suffix == ".md" and SCRIPT_REL not in path.read_text(encoding="utf-8"):
        raise PermissionError(f"Refusing to overwrite foreign report: {path.relative_to(ROOT)}")


def add_metadata(frame: pd.DataFrame, purpose: str) -> pd.DataFrame:
    result = frame.copy()
    result["source_files"] = "data/processed/noise_pedestrian_integrated_2025.csv"
    result["analysis_period"] = "2025-01-01 to 2025-12-31"
    result["feature_year"] = 2025
    result["output_purpose"] = purpose
    result["generation_script"] = SCRIPT_REL
    result["generated_at"] = timestamp()
    return result


def permutation_spearman(x: np.ndarray, y: np.ndarray, seed: int) -> tuple[float, float]:
    xr = stats.rankdata(x)
    yr = stats.rankdata(y)
    xr = (xr - xr.mean()) / np.sqrt(np.sum((xr - xr.mean()) ** 2))
    yr = (yr - yr.mean()) / np.sqrt(np.sum((yr - yr.mean()) ** 2))
    observed = float(np.dot(xr, yr))
    rng = np.random.default_rng(seed)
    exceed = 0
    remaining = PERMUTATIONS
    while remaining:
        size = min(10_000, remaining)
        permutations = np.vstack([rng.permutation(yr) for _ in range(size)])
        values = permutations @ xr
        exceed += int(np.sum(np.abs(values) >= abs(observed) - 1e-15))
        remaining -= size
    return observed, (exceed + 1) / (PERMUTATIONS + 1)


def correlation_table(data: pd.DataFrame) -> pd.DataFrame:
    rows = []
    seed_offset = 0
    for buffer_m in (250, 500, 1000):
        subset = data.loc[data["buffer_m"].eq(buffer_m)]
        for label, predictor in PREDICTORS.items():
            clean = subset[["device_id", OUTCOME, predictor]].dropna()
            x, y = clean[predictor].to_numpy(), clean[OUTCOME].to_numpy()
            pearson = stats.pearsonr(x, y)
            spearman, permutation_p = permutation_spearman(x, y, RANDOM_SEED + seed_offset)
            asymptotic = stats.spearmanr(x, y)
            rows.append({
                "buffer_m": buffer_m,
                "specification_role": "primary" if buffer_m == 500 else "buffer_sensitivity",
                "predictor_role": label,
                "predictor": predictor,
                "outcome": OUTCOME,
                "n": len(clean),
                "pearson_r": pearson.statistic,
                "pearson_p_value": pearson.pvalue,
                "spearman_rho": spearman,
                "spearman_asymptotic_p_value": asymptotic.pvalue,
                "spearman_permutation_p_value": permutation_p,
                "permutation_draws": PERMUTATIONS,
                "random_seed": RANDOM_SEED + seed_offset,
            })
            seed_offset += 1
    return add_metadata(pd.DataFrame(rows), "Pearson and Spearman associations with small-sample permutation inference")


def fit_model(frame: pd.DataFrame, predictors: list[str]):
    clean = frame[["device_id", OUTCOME] + predictors].dropna().copy()
    X = sm.add_constant(clean[predictors], has_constant="add")
    fit = sm.OLS(clean[OUTCOME], X).fit()
    influence = fit.get_influence()
    diagnostics = clean[["device_id"]].copy()
    diagnostics["studentized_residual"] = influence.resid_studentized_external
    diagnostics["leverage"] = influence.hat_matrix_diag
    diagnostics["cooks_distance"] = influence.cooks_distance[0]
    return clean, fit, diagnostics


def model_table(data: pd.DataFrame) -> tuple[pd.DataFrame, dict[tuple[int, str], object]]:
    model_specs = []
    for buffer_m in (250, 500, 1000):
        model_specs.append((buffer_m, "simple_pedestrian_mean", [PREDICTORS["pedestrian_mean"]]))
    model_specs.extend([
        (500, "alternative_pedestrian_intensity", [PREDICTORS["pedestrian_intensity_sum"]]),
        (500, "exploratory_adjusted_2024_bar_capacity", [PREDICTORS["pedestrian_mean"], "total_bar_capacity_2024_baseline"]),
    ])
    rows = []
    fits = {}
    for buffer_m, model_name, predictors in model_specs:
        clean, fit, diagnostics = fit_model(data.loc[data["buffer_m"].eq(buffer_m)], predictors)
        fits[(buffer_m, model_name)] = fit
        max_cook = diagnostics.loc[diagnostics["cooks_distance"].idxmax()]
        max_lev = diagnostics.loc[diagnostics["leverage"].idxmax()]
        max_resid = diagnostics.loc[diagnostics["studentized_residual"].abs().idxmax()]
        ci = fit.conf_int(alpha=0.05)
        for term in fit.params.index:
            rows.append({
                "buffer_m": buffer_m,
                "specification_role": "primary" if buffer_m == 500 else "buffer_sensitivity",
                "model": model_name,
                "outcome": OUTCOME,
                "term": term,
                "n": int(fit.nobs),
                "estimate": fit.params[term],
                "standard_error": fit.bse[term],
                "t_value": fit.tvalues[term],
                "p_value": fit.pvalues[term],
                "ci_95_lower": ci.loc[term, 0],
                "ci_95_upper": ci.loc[term, 1],
                "r_squared": fit.rsquared,
                "adjusted_r_squared": fit.rsquared_adj,
                "residual_df": fit.df_resid,
                "max_cooks_distance": max_cook["cooks_distance"],
                "max_cooks_device_id": max_cook["device_id"],
                "max_leverage": max_lev["leverage"],
                "max_leverage_device_id": max_lev["device_id"],
                "max_abs_studentized_residual": abs(max_resid["studentized_residual"]),
                "max_abs_studentized_residual_device_id": max_resid["device_id"],
            })
    return add_metadata(pd.DataFrame(rows), "Exploratory OLS models and influence diagnostics"), fits


def leave_one_out_table(data: pd.DataFrame) -> pd.DataFrame:
    primary = data.loc[data["buffer_m"].eq(500), ["device_id", OUTCOME, PREDICTORS["pedestrian_mean"]]].dropna()
    rows = []
    for omitted in primary["device_id"]:
        sample = primary.loc[~primary["device_id"].eq(omitted)]
        rho = stats.spearmanr(sample[PREDICTORS["pedestrian_mean"]], sample[OUTCOME]).statistic
        X = sm.add_constant(sample[[PREDICTORS["pedestrian_mean"]]], has_constant="add")
        fit = sm.OLS(sample[OUTCOME], X).fit()
        rows.append({
            "buffer_m": 500,
            "omitted_device_id": omitted,
            "n_after_omission": len(sample),
            "spearman_rho": rho,
            "ols_intercept": fit.params["const"],
            "ols_pedestrian_mean_slope": fit.params[PREDICTORS["pedestrian_mean"]],
            "ols_pedestrian_mean_p_value": fit.pvalues[PREDICTORS["pedestrian_mean"]],
            "r_squared": fit.rsquared,
        })
    return add_metadata(pd.DataFrame(rows), "Leave-one-noise-sensor-out stability of primary Spearman association and OLS slope")


def make_scatter(data: pd.DataFrame, fit) -> None:
    xcol = PREDICTORS["pedestrian_mean"]
    sample = data.loc[data["buffer_m"].eq(500), ["device_id", OUTCOME, xcol]].dropna().sort_values(xcol)
    x = sample[xcol].to_numpy()
    pred_x = np.linspace(x.min(), x.max(), 200)
    prediction = fit.get_prediction(sm.add_constant(pd.DataFrame({xcol: pred_x}), has_constant="add")).summary_frame()
    fig, ax = plt.subplots(figsize=(9.5, 6.2))
    ax.scatter(sample[xcol], sample[OUTCOME], s=55, color="#2166AC", edgecolor="white", linewidth=0.7, zorder=3)
    ax.plot(pred_x, prediction["mean"], color="#B2182B", linewidth=1.8, label="OLS fit")
    ax.fill_between(pred_x, prediction["mean_ci_lower"], prediction["mean_ci_upper"], color="#B2182B", alpha=0.14, label="95% mean CI")
    for row in sample.itertuples(index=False):
        label = row.device_id.replace("ICTMicroclimate-", "")
        ax.annotate(label, (getattr(row, xcol), getattr(row, OUTCOME)), xytext=(5, 5), textcoords="offset points", fontsize=8)
    ax.set(title="Night-time noise and observed pedestrian activity at 500 m",
           xlabel="Mean night-time hourly pedestrian count across matched sensors",
           ylabel="2025 night-time median noise (dataset units)")
    ax.text(0, -0.17, "Labels are noise-sensor IDs. n=10 because one sensor has no pedestrian counter within 500 m. Exploratory association; not causal.",
            transform=ax.transAxes, fontsize=9, color="#444444")
    ax.grid(axis="both", color="#E5E7EB", linewidth=0.8)
    ax.spines[["top", "right"]].set_visible(False)
    ax.legend(frameon=False, loc="best")
    fig.tight_layout()
    fig.savefig(SCATTER_PATH, dpi=220, bbox_inches="tight")
    plt.close(fig)


def make_sensitivity(correlations: pd.DataFrame, models: pd.DataFrame) -> None:
    corr = correlations.loc[correlations["predictor_role"].eq("pedestrian_mean")].sort_values("buffer_m")
    slopes = models.loc[(models["model"].eq("simple_pedestrian_mean")) & (models["term"].eq(PREDICTORS["pedestrian_mean"]))].sort_values("buffer_m")
    fig, axes = plt.subplots(1, 2, figsize=(10.5, 4.9))
    axes[0].plot(corr["buffer_m"], corr["spearman_rho"], marker="o", color="#2166AC", linewidth=1.8)
    axes[0].axhline(0, color="#777777", linewidth=0.8)
    axes[0].set(title="Spearman association", xlabel="Buffer distance (m)", ylabel="Spearman rho", xticks=[250, 500, 1000])
    axes[1].errorbar(slopes["buffer_m"], slopes["estimate"],
                     yerr=[slopes["estimate"] - slopes["ci_95_lower"], slopes["ci_95_upper"] - slopes["estimate"]],
                     fmt="o-", color="#B2182B", capsize=4, linewidth=1.8)
    axes[1].axhline(0, color="#777777", linewidth=0.8)
    axes[1].set(title="Simple OLS slope", xlabel="Buffer distance (m)", ylabel="Dataset units per pedestrian count", xticks=[250, 500, 1000])
    for ax in axes:
        ax.grid(color="#E5E7EB", linewidth=0.8)
        ax.spines[["top", "right"]].set_visible(False)
        ax.axvline(500, color="#555555", linestyle="--", linewidth=0.9, alpha=0.7)
    fig.suptitle("Buffer-distance sensitivity of the pedestrian-noise association", fontsize=13)
    fig.text(0.5, 0.01, "500 m is the pre-specified primary distance. Each estimate uses noise sensors with non-missing matched pedestrian activity.", ha="center", fontsize=9)
    fig.tight_layout(rect=[0, 0.04, 1, 0.94])
    fig.savefig(SENSITIVITY_PATH, dpi=220, bbox_inches="tight")
    plt.close(fig)


def fmt(value: float, digits: int = 3) -> str:
    return "NA" if pd.isna(value) else f"{value:.{digits}f}"


def write_report(data: pd.DataFrame, correlations: pd.DataFrame, models: pd.DataFrame, loo: pd.DataFrame) -> None:
    c = correlations[(correlations.buffer_m == 500) & (correlations.predictor_role == "pedestrian_mean")].iloc[0]
    m = models[(models.buffer_m == 500) & (models.model == "simple_pedestrian_mean") & (models.term == PREDICTORS["pedestrian_mean"])].iloc[0]
    alt = models[(models.buffer_m == 500) & (models.model == "alternative_pedestrian_intensity") & (models.term == PREDICTORS["pedestrian_intensity_sum"])].iloc[0]
    adj = models[(models.buffer_m == 500) & (models.model == "exploratory_adjusted_2024_bar_capacity") & (models.term == PREDICTORS["pedestrian_mean"])].iloc[0]
    sensitivity = correlations[correlations.predictor_role.eq("pedestrian_mean")].sort_values("buffer_m")
    report = f"""# 2025 Pedestrian Activity and Night-time Noise Statistical Results

Generated by `{SCRIPT_REL}`.

## Scope and analysis unit

The analysis uses one row per noise sensor at each buffer distance. The 500 m specification is primary. The 250 m and 1,000 m rows are sensitivity specifications and are not pooled as 33 independent observations. Pedestrian counts represent observed movements past counters, not unique people. Results are exploratory associations and do not establish causal effects.

The physical unit, sensor model, calibration, mounting height, noise-specific quality flags, and meaning of zero values could not be authoritatively confirmed. We therefore report recorded Noise values in dataset units.

The formal daily pedestrian metric is `daily_activity_analysis_value`, defined as the mean daily total among dates with all 24 hourly records. The observed-day field `avg_daily_pedestrian_count` remains descriptive only. The statistical models below use the pre-specified night-time hourly metric rather than either daily field.

## Primary 500 m association

Ten of the 11 noise sensors have at least one matched pedestrian counter within 500 m. For 2025 night-time median noise and mean night-time hourly pedestrian activity, Pearson r is {fmt(c.pearson_r)} (p={fmt(c.pearson_p_value)}), while the primary Spearman rho is {fmt(c.spearman_rho)}. The two-sided 99,999-draw permutation p-value is {fmt(c.spearman_permutation_p_value)}. With n={int(c.n)}, effect direction and stability matter more than threshold-based significance claims.

## Regression results

The simple 500 m OLS slope is {fmt(m.estimate, 4)} dataset units per pedestrian count (95% CI {fmt(m.ci_95_lower, 4)} to {fmt(m.ci_95_upper, 4)}; p={fmt(m.p_value)}; R-squared={fmt(m.r_squared)}). The alternative activity-intensity slope is {fmt(alt.estimate, 6)} (p={fmt(alt.p_value)}; R-squared={fmt(alt.r_squared)}). After adding bar capacity as a **lagged 2024 contextual baseline, not a 2025 measurement**, the pedestrian-mean coefficient is {fmt(adj.estimate, 4)} (p={fmt(adj.p_value)}). This adjusted model has only {int(adj.n)} observations and must not be treated as confirmatory.

The largest Cook's distance in the primary model is {fmt(m.max_cooks_distance)} for {m.max_cooks_device_id}; the largest leverage is {fmt(m.max_leverage)} for {m.max_leverage_device_id}; and the largest absolute externally studentized residual is {fmt(m.max_abs_studentized_residual)} for {m.max_abs_studentized_residual_device_id}.

## Leave-one-sensor-out stability

Across the ten leave-one-out samples, Spearman rho ranges from {fmt(loo.spearman_rho.min())} to {fmt(loo.spearman_rho.max())}. The simple OLS slope ranges from {fmt(loo.ols_pedestrian_mean_slope.min(), 4)} to {fmt(loo.ols_pedestrian_mean_slope.max(), 4)}. These ranges show how strongly the result depends on individual monitored locations.

## Buffer sensitivity

For the mean night-time pedestrian metric, Spearman rho is """ + ", ".join(
        f"{int(row.buffer_m)} m: {fmt(row.spearman_rho)}" for row in sensitivity.itertuples()
    ) + ". The corresponding simple-regression coefficients and confidence intervals are reported in `pedestrian_noise_models_2025.csv`. Differences across buffers reflect changing matched counter sets and should not be interpreted as separate independent samples.\n\n" + """## Reporting language

The analysis did not identify a stable simple association between the selected pedestrian measure and night-time recorded Noise values at these monitored locations.

The data do not support claims that pedestrian activity causes recorded Noise values, that results represent all of Melbourne, or that summed sensor means count unique pedestrians. The business-capacity fields are lagged 2024 contextual baselines, not contemporaneous 2025 measurements.

## Outputs

- `data/processed/pedestrian_noise_correlations_2025.csv`
- `data/processed/pedestrian_noise_models_2025.csv`
- `data/processed/pedestrian_noise_leave_one_out_2025.csv`
- `figures/pedestrian_nighttime_noise_500m_2025.png`
- `figures/pedestrian_noise_buffer_sensitivity_2025.png`
"""
    REPORT_PATH.write_text(report, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()
    for path in OUTPUTS:
        ensure_output(path, args.overwrite)
    data = pd.read_csv(INPUT)
    required = {"device_id", "buffer_m", OUTCOME, *PREDICTORS.values(), "total_bar_capacity_2024_baseline"}
    missing = sorted(required - set(data.columns))
    if missing:
        raise ValueError(f"Missing input fields: {', '.join(missing)}")
    if len(data) != 33 or data.duplicated(["device_id", "buffer_m"]).any():
        raise ValueError("Input must contain 33 unique device_id + buffer_m rows")
    if data.groupby("buffer_m")["device_id"].nunique().to_dict() != {250: 11, 500: 11, 1000: 11}:
        raise ValueError("Each buffer must contain 11 noise sensors")
    correlations = correlation_table(data)
    models, fits = model_table(data)
    loo = leave_one_out_table(data)
    primary_fit = fits[(500, "simple_pedestrian_mean")]
    PROCESSED.mkdir(parents=True, exist_ok=True)
    FIGURES.mkdir(parents=True, exist_ok=True)
    correlations.to_csv(CORRELATION_PATH, index=False)
    models.to_csv(MODEL_PATH, index=False)
    loo.to_csv(LOO_PATH, index=False)
    make_scatter(data, primary_fit)
    make_sensitivity(correlations, models)
    write_report(data, correlations, models, loo)
    print(f"Created {CORRELATION_PATH.relative_to(ROOT)}: {len(correlations)} rows")
    print(f"Created {MODEL_PATH.relative_to(ROOT)}: {len(models)} rows")
    print(f"Created {LOO_PATH.relative_to(ROOT)}: {len(loo)} rows")
    print(f"Created {SCATTER_PATH.relative_to(ROOT)}")
    print(f"Created {SENSITIVITY_PATH.relative_to(ROOT)}")
    print(f"Created {REPORT_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
