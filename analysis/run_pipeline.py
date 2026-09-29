"""Check or run the complete R/Python analysis pipeline safely.

The default action is read-only validation. Regeneration requires both
``--run`` and ``--overwrite`` because producing scripts replace their own
processed outputs and figures.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
EXPECTED_PYTHON = (3, 12, 14)
REQUIRED_INPUTS = {
    "data/raw/microclimate_sensors.csv": "85f784a66356cbc0eba0793d95faec8801627baf03485a3a15fb17c74e03eb01",
    "data/raw/pedestrian_counts_2019_2024.csv": "c03352478451366e4469344bd404724a2cd3d4ee2f36a85ae7a5f3b044102e58",
    "data/raw/pedestrian-counting-system-sensor-locations.csv": "f191b2c8901a50750676a1fa99799c7b3cb51ff7e952198dc962871648132de2",
    "data/raw/bars-and-pubs-with-patron-capacity.csv": "4365cc257ccb4dc2438513d957da4f631827b990107025c608a0a0cda63ea620",
    "data/raw/cafes-and-restaurants-with-seating-capacity.csv": "61cb34f5ee0cf20c6b0031f252193ea94b8458d97db87b46b1a98372482c4028",
    "data/raw/business-establishments-with-address-and-industry-classification.csv": "0f285d4b2d9d7279f28b750ec700dd506cad60976f3767c29f06b145ecb9aa0d",
}
REQUIRED_SCRIPTS = (
    "analysis/check_r_environment.R",
    "analysis/run_all.R",
    "analysis/noise_zero_value_sensitivity.R",
    "analysis/pedestrian_activity_integration_multiyear.py",
    "analysis/pedestrian_noise_statistical_analysis_2025.py",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_rscript(requested: str | None) -> str:
    candidates = [requested, shutil.which("Rscript")]
    if os.name == "nt":
        candidates.extend([
            r"C:\Program Files\R\R-4.5.2\bin\Rscript.exe",
            r"C:\Program Files\R\R-4.5.2\bin\x64\Rscript.exe",
        ])
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate).resolve())
    raise RuntimeError("Rscript was not found. Install R 4.5.2 or pass --rscript PATH.")


def subprocess_environment() -> dict[str, str]:
    environment = os.environ.copy()
    if os.name == "nt":
        # C.UTF-8 is a Unix locale and can corrupt non-ASCII paths in Windows R.
        for name in ("LANG", "LC_ALL", "LC_CTYPE"):
            if environment.get(name, "").upper() in {"C.UTF-8", "C.UTF8"}:
                environment.pop(name, None)
    runtime = ROOT / "renv" / "runtime"
    environment["RENV_PATHS_ROOT"] = str(runtime)
    environment["RENV_PATHS_SANDBOX"] = str(runtime / "sandbox")
    return environment


def run_command(command: list[str], environment: dict[str, str]) -> None:
    print("+", subprocess.list2cmdline(command), flush=True)
    subprocess.run(command, cwd=ROOT, env=environment, check=True)


def check_python() -> None:
    current = sys.version_info[:3]
    if current != EXPECTED_PYTHON:
        raise RuntimeError(
            f"Python {'.'.join(map(str, EXPECTED_PYTHON))} is required; "
            f"found {sys.version.split()[0]}."
        )
    locked_packages: dict[str, str] = {}
    for raw in (ROOT / "requirements.txt").read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.count("==") != 1:
            raise RuntimeError(f"requirements.txt contains an unpinned entry: {line}")
        package, version = line.split("==", 1)
        locked_packages[package] = version
    mismatches = []
    for package, expected in locked_packages.items():
        try:
            installed = importlib.metadata.version(package)
        except importlib.metadata.PackageNotFoundError:
            mismatches.append(f"{package} is not installed")
            continue
        if installed != expected:
            mismatches.append(f"{package} expected {expected}, found {installed}")
    if mismatches:
        raise RuntimeError("Python dependency check failed: " + "; ".join(mismatches))
    print(f"PASS Python {sys.version.split()[0]} and {len(locked_packages)} pinned packages")


def check_files(verify_hashes: bool) -> None:
    required = (*REQUIRED_INPUTS, *REQUIRED_SCRIPTS)
    missing = [relative for relative in required if not (ROOT / relative).is_file()]
    if missing:
        raise RuntimeError("Missing required files: " + ", ".join(missing))
    print(f"PASS {len(REQUIRED_SCRIPTS)} pipeline scripts and {len(REQUIRED_INPUTS)} inputs exist")
    if not verify_hashes:
        print("SKIP input SHA-256 verification (--skip-hashes was supplied)")
        return
    for relative, expected in REQUIRED_INPUTS.items():
        actual = sha256(ROOT / relative)
        if actual != expected:
            raise RuntimeError(f"Checksum mismatch for {relative}: expected {expected}, found {actual}")
        print(f"PASS SHA-256 {relative}")


def check_r(rscript: str, environment: dict[str, str]) -> None:
    run_command([rscript, "--vanilla", "analysis/check_r_environment.R"], environment)


def run_pipeline(rscript: str, environment: dict[str, str]) -> None:
    stages = [
        [rscript, "--vanilla", "analysis/run_all.R"],
        [sys.executable, "analysis/pedestrian_activity_integration_multiyear.py", "--overwrite"],
        [rscript, "--vanilla", "analysis/noise_zero_value_sensitivity.R"],
        [sys.executable, "analysis/pedestrian_noise_statistical_analysis_2025.py", "--overwrite"],
    ]
    for command in stages:
        run_command(command, environment)
    print("Pipeline completed: R core, 2025 pedestrian integration, zero sensitivity, and 2025 statistics.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate or regenerate the complete ETC5543 analysis pipeline")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", action="store_true", help="Validate environments, scripts, inputs and checksums (default)")
    action.add_argument("--run", action="store_true", help="Regenerate the complete pipeline")
    parser.add_argument("--overwrite", action="store_true", help="Required with --run; producing scripts replace their own outputs")
    parser.add_argument("--skip-hashes", action="store_true", help="Skip input checksum verification during a check")
    parser.add_argument("--rscript", help="Path to the R 4.5.2 Rscript executable")
    args = parser.parse_args()
    if args.run and not args.overwrite:
        parser.error("--run requires --overwrite because existing generated outputs will be replaced")
    if args.overwrite and not args.run:
        parser.error("--overwrite is valid only with --run")

    os.chdir(ROOT)
    environment = subprocess_environment()
    rscript = find_rscript(args.rscript)
    check_python()
    check_files(not args.skip_hashes)
    check_r(rscript, environment)
    if args.run:
        run_pipeline(rscript, environment)
    else:
        print("Read-only reproducibility check passed. Use --run --overwrite to regenerate outputs.")


if __name__ == "__main__":
    main()
