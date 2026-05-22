#!/usr/bin/env bash
#SBATCH --job-name=clover_only
#SBATCH --partition=work
#SBATCH --gres=mps:50
#SBATCH --qos=medium
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=02:00:00
#SBATCH --output=/home/export/aarusha/Performance/logs/clover_only_%j.out
#SBATCH --error=/home/export/aarusha/Performance/logs/clover_only_%j.err

# Re-run CLOVER ONLY (PCA-FGC head-to-head data already collected cleanly in
# pca_fgc_clover_headtohead.csv). The earlier run misread N because CLOVER
# parses N from the first digit of the filename and the old names contained
# "d3" — files have been renamed to <N>-<dataset>.txt to fix this.
#
# Runs bitonic / warpwise / hubs on all 15 mesh files (3 datasets × 5 N).

set -u
mkdir -p /home/export/aarusha/Performance/logs
cd /home/export/aarusha/clover-knn

ls -la meshes/ | head -20
cd build
echo "=== nvidia-smi ==="
nvidia-smi || true

RESULT_CSV=/home/export/aarusha/Performance/clover_headtohead.csv
echo "algorithm,filename,n,k,rep,time_ns" > "$RESULT_CSV"

for alg in 0 1 2; do
  alg_name=$(case "$alg" in 0) echo bitonic;; 1) echo warpwise;; 2) echo hubs;; esac)
  echo "=== CLOVER algorithm=$alg ($alg_name) ==="
  log=/home/export/aarusha/Performance/logs/clover_only_${alg_name}_$SLURM_JOB_ID.log
  ./linear-scans $alg 2>&1 | tee "$log"

  # Mesh-path output format (in the log):
  #   ../meshes/100000-hgcal.txt           <-- filename (preceded by some timestamp on same line)
  #   Processing file: 100000-hgcal.txt, Length: 100000
  #   (100000, 40, [time_ns_run1, time_ns_run2, ...]),
  # Parse: for each "Processing file" line keep the filename; on subsequent
  # "(N, k, [...])" lines emit one row per run-time integer.
  awk -v a="$alg_name" '
    /^Processing file:/ {
      # Extract filename between "Processing file: " and ", Length:"
      match($0, /Processing file: ([^,]+),/, m);
      fname = m[1];
      next
    }
    /^\(.*\[.*\]\),?$/ {
      # Strip parens, brackets, commas; tokenize
      line = $0
      gsub(/[()\[\],]/, " ", line)
      n_tok = split(line, t, /[ \t]+/)
      # Skip empty leading token if any
      i0 = 1; while (i0 <= n_tok && t[i0] == "") i0++
      # t[i0] = N, t[i0+1] = k, t[i0+2..] = times
      if (n_tok < i0+2) next
      n = t[i0]; k = t[i0+1]
      rep = 0
      for (i = i0+2; i <= n_tok; i++) {
        if (t[i] ~ /^[0-9]+$/) {
          rep++
          print a "," fname "," n "," k "," rep "," t[i]
        }
      }
    }
  ' "$log" >> "$RESULT_CSV"
done

echo "=== CLOVER head-to-head re-run done ==="
ls -la "$RESULT_CSV"
wc -l "$RESULT_CSV"
echo "--- sample ---"
head -5 "$RESULT_CSV"
echo "..."
tail -5 "$RESULT_CSV"
