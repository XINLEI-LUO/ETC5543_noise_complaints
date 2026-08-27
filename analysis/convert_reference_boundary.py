"""Convert the downloaded official municipal GeoJSON to base-R-friendly CSV."""

import csv
import json
from pathlib import Path

source = Path("data/reference/melbourne_municipal_boundary.geojson")
target = Path("data/reference/melbourne_municipal_boundary_coordinates.csv")

with source.open(encoding="utf-8") as handle:
    data = json.load(handle)

geometry = data["features"][0]["geometry"]
polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]

with target.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["ring_id", "longitude", "latitude"])
    ring_id = 0
    for polygon in polygons:
        for ring in polygon:
            ring_id += 1
            for longitude, latitude, *_ in ring:
                writer.writerow([ring_id, longitude, latitude])
