#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ARES — MNIST image classification: one-time preparation
#
#  Run this ON A KATANA LOGIN NODE, not inside a job.
#
#  It does the two steps that need outbound internet:
#    1. pulls the PyTorch container into scratch
#    2. downloads MNIST into scratch
#
#  After this, the job itself runs entirely offline — which matters
#  if compute nodes have no direct internet access.
#
#  Safe to re-run: both steps are skipped if already done.
# ═══════════════════════════════════════════════════════════════

# ── Parameters (keep in step with ares_mnist_classification.pbs) ─
OUTDIR="/srv/scratch/$USER/ares-mnist-classification"
DATADIR="/srv/scratch/$USER/ares-mnist-classification/data"
CONTAINER_URI="docker://pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime"
# ───────────────────────────────────────────────────────────────

set -euo pipefail

CACHE_ROOT="/srv/scratch/$USER/.ares"
SIF="$CACHE_ROOT/containers/pytorch-2.4.0-cuda12.1.sif"

echo "========================================"
echo "  ARES MNIST classification — prepare"
echo "========================================"
echo ""

if [ ! -d "/srv/scratch/$USER" ]; then
    echo "ERROR: /srv/scratch/$USER does not exist."
    echo "Are you on Katana? Scratch is created on first login."
    exit 1
fi

mkdir -p "$OUTDIR" "$DATADIR" "$CACHE_ROOT/containers" "$CACHE_ROOT/tmp"

# Katana may route outbound traffic through a proxy. If the environment
# already defines one, apptainer and torchvision both pick it up; these
# lines just make that explicit in the log.
if [ -n "${HTTPS_PROXY:-${https_proxy:-}}" ]; then
    echo "Using proxy: ${HTTPS_PROXY:-$https_proxy}"
    echo ""
fi

export APPTAINER_CACHEDIR="$CACHE_ROOT/cache"
export APPTAINER_TMPDIR="$CACHE_ROOT/tmp"
export SINGULARITY_CACHEDIR="$APPTAINER_CACHEDIR"
export SINGULARITY_TMPDIR="$APPTAINER_TMPDIR"
mkdir -p "$APPTAINER_CACHEDIR"

# ── 1. Container runtime ────────────────────────────────────────
if command -v apptainer > /dev/null 2>&1; then
    RUNTIME="apptainer"
elif command -v singularity > /dev/null 2>&1; then
    RUNTIME="singularity"
else
    module load apptainer 2> /dev/null || module load singularity 2> /dev/null || true
    if command -v apptainer > /dev/null 2>&1; then
        RUNTIME="apptainer"
    elif command -v singularity > /dev/null 2>&1; then
        RUNTIME="singularity"
    else
        echo "ERROR: no container runtime available."
        echo "Ask ResTech which module provides apptainer or singularity on Katana."
        exit 1
    fi
fi
echo "[1/2] Container runtime: $RUNTIME"

if [ -f "$SIF" ]; then
    echo "      Image already cached: $SIF"
else
    echo "      Pulling $CONTAINER_URI"
    echo "      (several GB — expect a few minutes)"
    rm -f "$SIF.partial"
    if ! "$RUNTIME" pull "$SIF.partial" "$CONTAINER_URI"; then
        rm -f "$SIF.partial"
        echo "ERROR: container pull failed. Check network access from this node."
        exit 1
    fi
    mv "$SIF.partial" "$SIF"
    echo "      Cached at: $SIF"
fi
echo ""

# ── 2. MNIST ────────────────────────────────────────────────────
echo "[2/2] MNIST dataset -> $DATADIR"
"$RUNTIME" exec -B /srv/scratch:/srv/scratch "$SIF" python3 -c "
from torchvision import datasets
for train in (True, False):
    datasets.MNIST('$DATADIR', train=train, download=True)
print('MNIST ready.')
"
echo ""

echo "========================================"
echo "  Prepared. Submit the job with:"
echo ""
echo "    qsub ares_mnist_classification.pbs"
echo ""
echo "  Results will appear in:"
echo "    $OUTDIR"
echo "========================================"
