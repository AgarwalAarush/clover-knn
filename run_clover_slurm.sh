#!/usr/bin/env bash
#SBATCH --job-name=clover_ht
#SBATCH --partition=work
#SBATCH --gres=mps:50
#SBATCH --qos=medium
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=/home/export/aarusha/Performance/logs/clover_ht_%j.out
#SBATCH --error=/home/export/aarusha/Performance/logs/clover_ht_%j.err

# CLOVER vs PCA-FGC head-to-head, sharing the same .txt input files.
#
# 1. Export matched datasets to clover-knn/meshes/:
#    - HGCAL d=3 at N=100k..5M (already done if files exist)
#    - synth_gauss   d=3 at N=100k..5M  (np.random.standard_normal, seed=42)
#    - synth_uniform d=3 at N=100k..5M  (np.random.uniform[0,1], seed=42)
# 2. Run CLOVER (bitonic + warpwise + hubs) on every txt file via mesh path
# 3. Run PCA-FGC + vanilla FGC on every txt file
# 4. Outputs: clover_headtohead.csv + pca_fgc_clover_headtohead.csv

set -u
mkdir -p /home/export/aarusha/Performance/logs
cd /home/export/aarusha/clover-knn

source ~/miniconda3/etc/profile.d/conda.sh
echo "=== mesh export step ==="
conda activate fgc-fast
python -u export_hgcal_d3.py
python -u export_synth.py
conda deactivate
ls -la meshes/

cd build
echo "=== nvidia-smi ==="
nvidia-smi || true

# ----- CLOVER on every .txt file -----
RESULT_CSV=/home/export/aarusha/Performance/clover_headtohead.csv
echo "algorithm,filename,n,k,rep,time_ns" > "$RESULT_CSV"

for alg in 0 1 2; do
  alg_name=$(case "$alg" in 0) echo bitonic;; 1) echo warpwise;; 2) echo hubs;; esac)
  echo "=== CLOVER algorithm=$alg ($alg_name) ==="
  log=/home/export/aarusha/Performance/logs/clover_ht_${alg_name}_$SLURM_JOB_ID.log
  ./linear-scans $alg 2>&1 | tee "$log"
  # Parse mesh-path output:
  #   filename
  #   (N, k, [run1_ns, run2_ns, ...])
  awk -v a="$alg_name" '
    /^\/home\/.*\.txt$/ { fname=$0; sub(/.*\//,"",fname); next }
    /^\(.*\[.*\]\),?$/ {
      gsub(/[()\[\],]/, " ", $0);
      split($0, t, " ");
      # t[1]=N t[2]=k t[3..]=times
      for (i=3; i<=length(t); i++) {
        if (t[i] ~ /^[0-9]+$/) {
          print a "," fname "," t[1] "," t[2] "," (i-2) "," t[i]
        }
      }
    }
  ' "$log" >> "$RESULT_CSV"
done

# ----- PCA-FGC + vanilla FGC on the same .txt files -----
cd /home/export/aarusha/Performance
echo "=== PCA-FGC + vanilla FGC head-to-head ==="
conda activate fgc-fast
export PYTHONPATH=/home/export/aarusha/FastGraphCompute-dev:${PYTHONPATH:-}
python -u pca_fgc_clover_headtohead.py
conda deactivate

echo "=== head-to-head done ==="
ls -la /home/export/aarusha/Performance/clover_headtohead.csv \
       /home/export/aarusha/Performance/pca_fgc_clover_headtohead.csv 2>&1
