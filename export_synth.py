"""Generate synthetic 3D txt files in CLOVER's mesh format.

Two distributions, matched N values to the HGCAL files in clover-knn/meshes/:
  - Gaussian (np.random.randn, std=1)  — matches our existing synth_pca_benchmark
  - Uniform [0,1]                        — matches CLOVER's published claim

Filenames embed both the distribution and N so the run script + downstream
parser can route them to the right comparison.
"""
import os
import sys
import numpy as np

OUT_DIR = "/home/export/aarusha/clover-knn/meshes"
SIZES = [100_000, 500_000, 1_000_000, 2_000_000, 5_000_000]
SEED = 42

os.makedirs(OUT_DIR, exist_ok=True)

for n in SIZES:
    for dist in ("gauss", "uniform"):
        # Filename starts with N so CLOVER's countVerticesInTXT() (which parses
        # N from the first digit in the filename) gets the right value.
        # The dataset-name segment is digit-free.
        path = os.path.join(OUT_DIR, f"{n}-synth{dist}.txt")
        if os.path.exists(path):
            print(f"  skip existing: {path}", flush=True); continue
        rng = np.random.default_rng(SEED + n + (0 if dist == "gauss" else 1))
        if dist == "gauss":
            data = rng.standard_normal((n, 3), dtype=np.float32)
        else:
            data = rng.uniform(0.0, 1.0, size=(n, 3)).astype(np.float32)
        print(f"  writing {dist} N={n}: {path}", flush=True)
        np.savetxt(path, data, fmt="%.6f")
        print(f"    done, size={os.path.getsize(path)//(1024*1024)} MB", flush=True)

print("DONE", flush=True)
