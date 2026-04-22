#!/bin/bash
# ═══════════════════════════════════════════════════════════════
#  ARES — Hello World workflow (local / Docker)
#  Runs the same hello world workflow locally using Docker.
#  Requires: Docker Desktop (Windows/Mac) or Docker Engine (Linux)
#
#  Docs: https://patricktung-unsw.github.io/ares-pages/workflows/hello-world/
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

OUTDIR="$HOME/ares-hello-world"
mkdir -p "$OUTDIR"

echo "========================================"
echo "  ARES Hello World — Local (Docker)"
echo "========================================"
echo ""
echo "Output directory: $OUTDIR"
echo ""

docker run --rm \
  -v "$OUTDIR:/output" \
  ubuntu:22.04 \
  bash -c '
    echo "========================================"
    echo "  ARES Hello World — Success"
    echo "========================================"  > /output/hello_world_result.txt
    echo "Timestamp : $(date)"                      >> /output/hello_world_result.txt
    echo "Hostname  : $(hostname)"                  >> /output/hello_world_result.txt
    echo "OS        : $(uname -o)"                  >> /output/hello_world_result.txt
    echo "CPUs      : $(nproc)"                     >> /output/hello_world_result.txt
    echo ""                                         >> /output/hello_world_result.txt
    echo "If you can read this, your local ARES"    >> /output/hello_world_result.txt
    echo "Docker setup is working correctly."       >> /output/hello_world_result.txt
    echo "========================================"  >> /output/hello_world_result.txt
    cat /output/hello_world_result.txt
  '

echo ""
echo "Result written to: $OUTDIR/hello_world_result.txt"
echo ""
echo "========================================"
echo "  ARES Hello World — Complete"
echo "========================================"
