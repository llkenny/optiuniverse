#!/usr/bin/env python3
"""Build the offline Horizons archive. Python 3 + curl; no runtime app dependency.

Requests are serial, resumable and cached. Never replace an archive until its body
has passed interpolation checks. Use --verify-only to check packaged checksums.
"""
import argparse
import csv
import datetime as dt
import gzip
import hashlib
import json
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "Modules/UniverseModule/Sources/UniverseModule/Assets/Ephemeris"
CACHE = ROOT / ".cache/ephemeris"
API = "https://ssd.jpl.nasa.gov/api/horizons.api"
BODIES = {"Mercury": 199, "Venus": 299, "Earth": 399, "Moon": 301,
          "Mars": 499, "Jupiter": 599, "Saturn": 699, "Uranus": 799,
          "Neptune": 899, "Pluto": 999}
J2000 = 2451545.0
START = -43200.0  # 2000-01-01 00:00 TDB
# One guard day includes the UTC/TDB offset at the very end of calendar year 2100.
END = (dt.datetime(2101, 1, 2) - dt.datetime(2000, 1, 1, 12)).total_seconds()


def fetch(url, parameters=None):
    key = hashlib.sha256(json.dumps([url, parameters], sort_keys=True).encode()).hexdigest()
    cached = CACHE / (key + ".gz")
    if cached.exists():
        return gzip.decompress(cached.read_bytes()).decode()
    command = [os.environ.get("EPHEMERIS_CURL_EXECUTABLE", "curl"),
               "--fail", "--silent", "--show-error", "--max-time", "180", url]
    if parameters:
        command += ["--get"]
        for key, value in parameters.items():
            command += ["--data-urlencode", key + "=" + value]
    for attempt in range(5):
        try:
            raw = subprocess.check_output(command)
            if parameters:
                response = json.loads(raw)
                if response.get("error") or "$$EOE" not in response.get("result", ""):
                    raise ValueError(response.get("error", response))
            cached.write_bytes(gzip.compress(raw, mtime=0))
            return raw.decode()
        except (subprocess.CalledProcessError, ValueError):
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)


def parameters(body):
    return {"format": "json", "COMMAND": f"'{body}'", "OBJ_DATA": "'NO'",
            "MAKE_EPHEM": "'YES'", "EPHEM_TYPE": "'VECTORS'", "CENTER": "'500@10'",
            "REF_PLANE": "'ECLIPTIC'", "REF_SYSTEM": "'ICRF'", "OUT_UNITS": "'KM-S'",
            "VEC_CORR": "'NONE'", "VEC_TABLE": "'2'", "TIME_TYPE": "'TDB'",
            "CSV_FORMAT": "'YES'", "CAL_TYPE": "'GREGORIAN'"}


def query(body, start, end, step):
    params = parameters(body)
    params.update(START_TIME=f"'JD{J2000 + start / 86400:.12f}'",
                  STOP_TIME=f"'JD{J2000 + end / 86400:.12f}'",
                  STEP_SIZE=f"'{int(step / 60)} m'")
    result = json.loads(fetch(API, params))["result"]
    rows = []
    for line in csv.reader(result.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()):
        # Grid epochs are known exactly; printed Julian days have finite precision.
        epoch = start + len(rows) * step
        vector = tuple(float(value) for value in line[2:8])
        if len(vector) != 6 or not all(math.isfinite(value) for value in vector):
            raise ValueError("Invalid Horizons state")
        rows.append((epoch, *vector))
    if not rows or abs(rows[-1][0] - end) > 0.001:
        raise ValueError("Incomplete Horizons coverage")
    source = re.search(r"Target body name:.*?\{source: (.*?)\}", result).group(1)
    return rows, source


def interpolate(left, right, epoch):
    duration = right[0] - left[0]
    u = (epoch - left[0]) / duration
    position, velocity = [], []
    for axis in range(3):
        p0, p1 = left[axis + 1], right[axis + 1]
        v0, v1 = left[axis + 4], right[axis + 4]
        position.append((2*u**3-3*u**2+1)*p0 + (u**3-2*u**2+u)*duration*v0
                        + (-2*u**3+3*u**2)*p1 + (u**3-u**2)*duration*v1)
        velocity.append((6*u**2-6*u)*p0/duration + (3*u**2-4*u+1)*v0
                        + (-6*u**2+6*u)*p1/duration + (3*u**2-2*u)*v1)
    return position + velocity


def errors(actual, expected):
    return (math.sqrt(sum((actual[i]-expected[i])**2 for i in range(3))),
            math.sqrt(sum((actual[i+3]-expected[i+3])**2 for i in range(3))))


def validated_grid(body, start, end, step, depth=0):
    # Four subdivisions supply all quarter-point checks, not just endpoints.
    samples, source = query(body, start, end, step / 4)
    kept = [samples[0]]
    maximum_position = maximum_velocity = 0.0
    for index in range(0, len(samples)-1, 4):
        left, right = samples[index], samples[index+4]
        residuals = [errors(interpolate(left, right, row[0]), row[1:])
                     for row in samples[index+1:index+4]]
        if any(p > 1.0 or v > 0.001 for p, v in residuals):
            if depth >= 6:
                raise ValueError("Interpolation could not meet error budget")
            # Refine the block in one batch instead of thousands of tiny API requests.
            return validated_grid(body, start, end, step/2, depth+1)
        else:
            kept.append(right)
            maximum_position = max(maximum_position, *(p for p, _ in residuals))
            maximum_velocity = max(maximum_velocity, *(v for _, v in residuals))
    return kept, source, maximum_position, maximum_velocity


def orientation_data():
    url = "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc"
    text = fetch(url)
    blocks = "\n".join(block.split("\\begintext")[0] for block in text.split("\\begindata")[1:])
    values = {}
    for key, numbers in re.findall(r"(BODY\d+_\w+)\s*=\s*\((.*?)\)", blocks, re.S):
        values[key] = [float(n.replace("D", "E")) for n in numbers.split()]
    for key, number in re.findall(r"(BODY\d+_MAX_PHASE_DEGREE)\s*=\s*(\d+)", blocks):
        values[key] = [float(number)]
    bodies = {}
    for name, body in {"Sun": 10, **BODIES}.items():
        prefix = f"BODY{body}_"
        system = body // 100
        degree = int(values.get(f"BODY{system}_MAX_PHASE_DEGREE", [1])[0])
        angles = values.get(f"BODY{system}_NUT_PREC_ANGLES", [])
        bodies[name] = {"poleRA": values[prefix+"POLE_RA"],
                        "poleDec": values[prefix+"POLE_DEC"], "meridian": values[prefix+"PM"],
                        "raTerms": values.get(prefix+"NUT_PREC_RA", []),
                        "decTerms": values.get(prefix+"NUT_PREC_DEC", []),
                        "meridianTerms": values.get(prefix+"NUT_PREC_PM", []),
                        "phasePolynomials": [angles[i:i+degree+1] for i in range(0, len(angles), degree+1)]}
    return {"source": url, "sourceSHA256": hashlib.sha256(text.encode()).hexdigest(), "bodies": bodies}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body", choices=BODIES, help="Regenerate one body")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest_path = OUTPUT / "manifest.json"
    if args.verify_only:
        manifest = json.loads(manifest_path.read_text())
        for entry in manifest["bodies"].values():
            assert hashlib.sha256((OUTPUT / entry["filename"]).read_bytes()).hexdigest() == entry["sha256"]
        print("All ephemeris checksums verified")
        return
    orientation = json.dumps(orientation_data(), indent=2) + "\n"
    (OUTPUT / "orientation.json").write_text(orientation)
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        "version": 1, "frame": "heliocentric-ecliptic-J2000", "timeScale": "TDB",
        "startSeconds": START, "endSeconds": END, "recordFormat": "little-endian-7-float64",
        "parameters": parameters("TARGET"), "bodies": {}}
    manifest["orientationSHA256"] = hashlib.sha256(orientation.encode()).hexdigest()
    manifest["endSeconds"] = END
    for name, body in BODIES.items():
        if args.body and args.body != name:
            continue
        print(f"Generating {name}", flush=True)
        all_rows, sources = [], set()
        pos_error = vel_error = 0.0
        step = 21600 if name == "Moon" else 86400
        # Ten-year-sized blocks keep requests below Horizons output limits.
        block_size = 3650 * 86400
        for start in range(int(START), int(END), block_size):
            end = min(start + block_size, END)
            rows, source, pos, vel = validated_grid(body, start, end, step)
            all_rows.extend(rows if not all_rows else rows[1:])
            sources.add(source)
            pos_error, vel_error = max(pos_error, pos), max(vel_error, vel)
            print(f"  through JD {J2000 + end/86400:.1f}: {len(all_rows)} records", flush=True)
        packed = b"".join(struct.pack("<7d", *row) for row in all_rows)
        filename = name.lower() + ".bin"
        (OUTPUT / filename).write_bytes(packed)
        manifest["bodies"][name] = {"id": body, "filename": filename, "count": len(all_rows),
            "sources": sorted(sources), "sha256": hashlib.sha256(packed).hexdigest(),
            "maximumCheckedPositionErrorKm": pos_error, "maximumCheckedVelocityErrorKmPerSecond": vel_error}
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        print(f"  {name}: {len(packed)} bytes, position error {pos_error:.6f} km", flush=True)


if __name__ == "__main__":
    main()
