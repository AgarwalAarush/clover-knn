"""Dump the first 3 columns of HGCAL recHitFeatures.npy as plain-text files
in the format CLOVER's mesh loader expects (one point per line, three
space-separated floats). Filenames must contain a numeric portion before
.txt — CLOVER parses N from the filename.
"""
import os
import sys
import numpy as np

OUT_DIR = "/home/export/aarusha/clover-knn/meshes"
HGCAL_PATH = "/home/export/rhe2/shareddata/recHitFeatures.npy"
SIZES = [100_000, 500_000, 1_000_000, 2_000_000, 5_000_000]

os.makedirs(OUT_DIR, exist_ok=True)
arr = np.load(HGCAL_PATH, mmap_mode='r')
print(f"Source shape: {arr.shape}", flush=True)

for n in SIZES:
    # Filename starts with N so CLOVER's countVerticesInTXT() (which parses
    # N from the first digit in the filename) gets the right value.
    out = os.path.join(OUT_DIR, f"{n}-hgcal.txt")
    if os.path.exists(out):
        print(f"  skip existing: {out}", flush=True); continue
    chunk = np.ascontiguousarray(arr[:n, :3])
    print(f"  writing N={n}: {out}", flush=True)
    np.savetxt(out, chunk, fmt="%.6f")
    print(f"    done, size={os.path.getsize(out)//(1024*1024)} MB", flush=True)

print("DONE", flush=True)
