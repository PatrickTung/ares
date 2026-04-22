# ═══════════════════════════════════════════════════════════════
#  ARES — Hello World workflow (local / Docker — Windows)
#  Requires: Docker Desktop for Windows
#
#  Docs: https://patricktung-unsw.github.io/ares-pages/workflows/hello-world/
# ═══════════════════════════════════════════════════════════════

$OUTDIR = "$HOME\ares-hello-world"
New-Item -ItemType Directory -Force -Path $OUTDIR | Out-Null

Write-Host "========================================"
Write-Host "  ARES Hello World — Local (Docker)"
Write-Host "========================================"
Write-Host ""
Write-Host "Output directory: $OUTDIR"
Write-Host ""

docker run --rm `
  -v "${OUTDIR}:/output" `
  ubuntu:22.04 `
  bash -c '
    {
      echo "========================================"
      echo "  ARES Hello World — Success"
      echo "========================================"
      echo "Timestamp : $(date)"
      echo "Hostname  : $(hostname)"
      echo "OS        : $(uname -o)"
      echo "CPUs      : $(nproc)"
      echo ""
      echo "If you can read this, your local ARES"
      echo "Docker setup is working correctly."
      echo "========================================"
    } | tee /output/hello_world_result.txt
  '

Write-Host ""
Write-Host "Result written to: $OUTDIR\hello_world_result.txt"
Write-Host ""
Write-Host "========================================"
Write-Host "  ARES Hello World — Complete"
Write-Host "========================================"
