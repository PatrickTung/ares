# ===============================================================
#  ARES - MNIST image classification (local / Docker - Windows)
#  Runs the same training script, in the same container image, as
#  the Katana job. Use it to check your changes before submitting.
#
#  Requires: Docker Desktop for Windows
#  The image is ~4 GB on first pull, then cached by Docker.
#  A GPU is used if one is visible; otherwise it trains on CPU.
#
#  Deliberately ASCII-only: Windows PowerShell 5.1 reads a UTF-8
#  file without a BOM as ANSI, and a stray non-ASCII byte can be
#  decoded as a smart quote that breaks the parse.
#
#  Docs: https://patricktung.github.io/ares/workflows/mnist-classification/
# ===============================================================

$ErrorActionPreference = "Stop"

$Image = if ($env:ARES_IMAGE) { $env:ARES_IMAGE } else { "pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime" }
$OutDir = if ($env:ARES_OUTDIR) { $env:ARES_OUTDIR } else { "$HOME\ares-mnist-classification" }
$Epochs = if ($env:ARES_EPOCHS) { $env:ARES_EPOCHS } else { "3" }

$SrcDir = (Resolve-Path "$PSScriptRoot\..\src").Path
New-Item -ItemType Directory -Force -Path $OutDir, "$OutDir\data" | Out-Null

Write-Host "========================================"
Write-Host "  ARES MNIST classification - Local"
Write-Host "========================================"
Write-Host ""
Write-Host "Image     : $Image"
Write-Host "Source    : $SrcDir\train_mnist.py"
Write-Host "Output    : $OutDir"
Write-Host ""

# Use the GPU only if Docker can actually see one - otherwise --gpus all
# makes the run fail outright rather than falling back.
$GpuArgs = @()
$Runtimes = docker info --format '{{.Runtimes}}'
if ($Runtimes -match 'nvidia') {
    Write-Host "NVIDIA runtime detected - training on GPU."
    $GpuArgs = @("--gpus", "all")
} else {
    Write-Host "No NVIDIA runtime - training on CPU (a few minutes)."
}
Write-Host ""

docker run --rm @GpuArgs `
  -v "${SrcDir}:/src:ro" `
  -v "${OutDir}:/output" `
  $Image `
  python3 /src/train_mnist.py `
    --data-dir /output/data `
    --outdir /output `
    --epochs $Epochs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Training failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Results written to: $OutDir"
Write-Host "  metrics.json          final accuracy and per-epoch history"
Write-Host "  confusion_matrix.txt  10x10, rows are true labels"
Write-Host "  training_log.txt      full run log"
Write-Host "  model.pt              trained weights"
Write-Host ""
Write-Host "========================================"
Write-Host "  ARES MNIST classification - Complete"
Write-Host "========================================"
