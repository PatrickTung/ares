#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ARES — MNIST image classification (local / Docker)
#  Runs the same training script, in the same container image, as
#  the Katana job. Use it to check your changes before submitting.
#
#  Requires: Docker Desktop (Windows/Mac) or Docker Engine (Linux)
#  The image is ~4 GB on first pull, then cached by Docker.
#  A GPU is used if one is visible; otherwise it trains on CPU.
#
#  Docs: https://patricktung.github.io/ares/workflows/mnist-classification/
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

IMAGE="${ARES_IMAGE:-pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime}"
OUTDIR="${ARES_OUTDIR:-$HOME/ares-mnist-classification}"
DATADIR="$OUTDIR/data"
EPOCHS="${ARES_EPOCHS:-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "$SCRIPT_DIR/../src" && pwd)"

mkdir -p "$OUTDIR" "$DATADIR"

echo "========================================"
echo "  ARES MNIST classification — Local"
echo "========================================"
echo ""
echo "Image     : $IMAGE"
echo "Source    : $SRC_DIR/train_mnist.py"
echo "Output    : $OUTDIR"
echo ""

# Use the GPU only if Docker can actually see one — otherwise --gpus all
# makes the run fail outright rather than falling back.
GPU_FLAG=""
if docker info --format '{{.Runtimes}}' 2> /dev/null | grep -q nvidia; then
    echo "NVIDIA runtime detected — training on GPU."
    GPU_FLAG="--gpus all"
else
    echo "No NVIDIA runtime — training on CPU (a few minutes)."
fi
echo ""

docker run --rm $GPU_FLAG \
  -v "$SRC_DIR:/src:ro" \
  -v "$OUTDIR:/output" \
  "$IMAGE" \
  python3 /src/train_mnist.py \
    --data-dir /output/data \
    --outdir /output \
    --epochs "$EPOCHS"

echo ""
echo "Results written to: $OUTDIR"
echo "  metrics.json          final accuracy and per-epoch history"
echo "  confusion_matrix.txt  10x10, rows are true labels"
echo "  training_log.txt      full run log"
echo "  model.pt              trained weights"
echo ""
echo "========================================"
echo "  ARES MNIST classification — Complete"
echo "========================================"
