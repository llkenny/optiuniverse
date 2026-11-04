#!/usr/bin/env python3
"""Independent Horizons checkpoints and CSPICE IAU/time reference fixtures.

Run with Python + spiceypy==8.3.0 (CSPICE N0067). Only this validation tool
uses SPICE; production generation and the Swift application do not require it.
"""
import bisect
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import random
import re
import struct

import spiceypy as spice
from generate_ephemeris import API, BODIES, CACHE, J2000, OUTPUT, ROOT, fetch, interpolate, parameters


def historical_utc_to_tdb(date, offsets):
    # CSPICE's LSK uses integral leap seconds. Convert pre-1972 UTC to TT using
    # the independent USNO drift table, then ask CSPICE for the TT-to-TDB conversion.
    utc = dt.datetime.fromisoformat(date)
    mjd = (utc - dt.datetime(1858, 11, 17)).total_seconds() / 86400
    _, base, reference, drift = next(row for row in reversed(offsets) if mjd >= row[0])
    tt = utc + dt.timedelta(seconds=32.184 + base + (mjd - reference) * drift)
    return float(spice.str2et(tt.isoformat(sep=" ") + " TDT"))


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((OUTPUT / "manifest.json").read_text())
    for filename, url in [
        ("pck00011.tpc", "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/pck00011.tpc"),
        ("naif0012.tls", "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls")
    ]:
        path = CACHE / filename
        path.write_text(fetch(url))
        spice.furnsh(str(path))
    assert spice.tkvrsn("toolkit") == "CSPICE_N0067"
    random_source = random.Random(20261013)
    dates = ["1977-01-01T00:00:00", "1977-09-05T12:56:01", "1979-03-05T12:05:00",
             "1980-11-12T23:46:00", "2012-08-25T00:00:00", "2000-01-01T00:00:00", "2016-12-31T23:59:59", "2017-01-01T00:00:00",
             "2026-10-13T09:45:12", "2050-06-17T12:34:56", "2100-12-31T23:59:59"]
    historical = [
        "1961-01-01T00:00:00", "1961-04-12T06:07:00", "1961-04-12T06:09:00",
        "1961-04-12T06:10:00", "1961-04-12T06:12:00", "1961-04-12T06:18:00",
        "1961-04-12T07:25:00", "1961-04-12T07:36:00", "1961-04-12T07:42:00",
        "1961-04-12T07:48:00", "1961-04-12T07:55:00", "1961-08-01T12:00:00",
        "1965-03-01T12:00:00", "1968-02-01T12:00:00", "1971-12-31T23:59:59",
        "1972-01-01T00:00:00"
    ]
    offset_source = "https://maia.usno.navy.mil/ser7/tai-utc.dat"
    offsets = [tuple(map(float, row)) for row in re.findall(
        r"=JD\s+([\d.]+)\s+TAI-UTC=\s+([\d.]+)\s+S\s+\+\s+\(MJD\s*-\s*([\d.]+)\)\s+X\s+([\d.]+)",
        fetch(offset_source)
    )]
    offsets = [(jd - 2_400_000.5, base, reference, drift) for jd, base, reference, drift in offsets]
    assert len(offsets) >= 13
    dates = historical + dates
    epochs = [historical_utc_to_tdb(date, offsets) if date < "1972" else float(spice.str2et(date))
              for date in dates]
    epochs += [random_source.uniform(manifest["startSeconds"] + 100, manifest["endSeconds"]-86400) for _ in range(16)]
    fixtures = {"sources": {"vectors": API, "orientation": "pck00011.tpc", "toolkit": spice.tkvrsn("toolkit"), "historicalUTC": offset_source},
                "times": [{"utc": date+"Z", "seconds": epoch} for date, epoch in zip(dates, epochs)], "states": []}
    for name, body in {"Sun": 10, **BODIES}.items():
        if name != "Sun":
            entry = manifest["bodies"][name]
            data = (OUTPUT / entry["filename"]).read_bytes()
            assert hashlib.sha256(data).hexdigest() == entry["sha256"]
            rows = list(struct.iter_unpack("<7d", data))
            grid = [row[0] for row in rows]
            params = parameters(body)
            params["TLIST"] = "'" + " ".join(f"{J2000 + epoch/86400:.12f}" for epoch in epochs) + "'"
            result = json.loads(fetch(API, params))["result"]
            lines = result.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()
            # Horizons sorts the discrete list by epoch.
            references = {}
            for line in lines:
                fields = line.split(",")
                printed_epoch = (float(fields[0])-J2000)*86400
                epoch = min(epochs, key=lambda value: abs(value-printed_epoch))
                references[epoch] = [float(value) for value in fields[2:8]]
            assert len(references) == len(epochs)
        maximum_error = 0.0
        for epoch in epochs:
            reference = [0.0]*6 if name == "Sun" else references[epoch]
            if name != "Sun":
                index = min(max(0, bisect.bisect_right(grid, epoch)-1), len(rows)-2)
                actual = interpolate(rows[index], rows[index+1], epoch)
                error = math.sqrt(sum((actual[i]-reference[i])**2 for i in range(3)))
                velocity_error = math.sqrt(sum((actual[i+3]-reference[i+3])**2 for i in range(3)))
                assert error < 10 and velocity_error < 0.001, (name, epoch, error, velocity_error)
                maximum_error = max(maximum_error, error)
            matrix = spice.pxform("IAU_"+name.upper(), "ECLIPJ2000", epoch)
            fixtures["states"].append({"body": name, "seconds": epoch,
                "position": reference[:3], "velocity": reference[3:], "orientation": matrix.T.flatten().tolist()})
        print(f"{name}: independent position error <= {maximum_error:.6f} km", flush=True)
    directory = ROOT / "Modules/UniverseModule/Tests/UniverseModuleTests/Fixtures"
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "ephemeris_references.json").write_text(json.dumps(fixtures, indent=2)+"\n")
    spice.kclear()


if __name__ == "__main__":
    main()
