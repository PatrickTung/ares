#!/usr/bin/env python3
"""
ARES — MNIST image classification.

Trains a small convolutional network on MNIST and writes metrics, a confusion
matrix and the trained weights to an output directory.

Only torch and torchvision are imported — both ship in the pytorch/pytorch
container image, so this runs with no pip install at job time.

Usage:
    python3 train_mnist.py --data-dir DATA --outdir OUT [--epochs 3] ...
"""

import argparse
import json
import os
import sys
import time

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

# MNIST channel statistics — the standard values used throughout the literature.
MNIST_MEAN = 0.1307
MNIST_STD = 0.3081
NUM_CLASSES = 10


class MnistCNN(nn.Module):
    """Two convolutional blocks, then a small classifier head.

    Deliberately ordinary. The point of this workflow is the container and HPC
    plumbing around the model, not the model — swap this class for your own and
    the rest of the pipeline keeps working.
    """

    def __init__(self, num_classes=NUM_CLASSES):
        super().__init__()
        self.block1 = nn.Sequential(
            nn.Conv2d(1, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.Conv2d(32, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),          # 28x28 -> 14x14
            nn.Dropout(0.25),
        )
        self.block2 = nn.Sequential(
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.Conv2d(64, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool2d(2),          # 14x14 -> 7x7
            nn.Dropout(0.25),
        )
        self.head = nn.Sequential(
            nn.Flatten(),
            nn.Linear(64 * 7 * 7, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(0.5),
            nn.Linear(128, num_classes),
        )

    def forward(self, x):
        return self.head(self.block2(self.block1(x)))


class Logger:
    """Writes to stdout (so it lands in the PBS log) and to a file at once."""

    def __init__(self, path):
        self.handle = open(path, "w", encoding="utf-8")

    def __call__(self, message=""):
        print(message, flush=True)
        self.handle.write(message + "\n")
        self.handle.flush()

    def close(self):
        self.handle.close()


def resolve_device(requested):
    if requested == "cpu":
        return torch.device("cpu")
    if requested == "cuda":
        if not torch.cuda.is_available():
            raise RuntimeError(
                "--device cuda was requested but torch.cuda.is_available() is False. "
                "Check that the job asked for a GPU (ngpus=1) and that the container "
                "was launched with --nv."
            )
        return torch.device("cuda")
    # auto
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def load_data(data_dir, batch_size, workers):
    """Build the MNIST train/test loaders.

    download=True is a no-op once the cache is populated, which is what lets this
    run on a compute node with no outbound internet — provided prepare.sh has
    already been run on the login node.
    """
    transform = transforms.Compose([
        transforms.ToTensor(),
        transforms.Normalize((MNIST_MEAN,), (MNIST_STD,)),
    ])
    train_set = datasets.MNIST(data_dir, train=True, download=True, transform=transform)
    test_set = datasets.MNIST(data_dir, train=False, download=True, transform=transform)

    train_loader = DataLoader(
        train_set, batch_size=batch_size, shuffle=True,
        num_workers=workers, pin_memory=torch.cuda.is_available(),
    )
    test_loader = DataLoader(
        test_set, batch_size=max(batch_size, 512), shuffle=False,
        num_workers=workers, pin_memory=torch.cuda.is_available(),
    )
    return train_loader, test_loader


def train_one_epoch(model, loader, optimiser, device):
    model.train()
    running_loss = 0.0
    seen = 0
    for images, labels in loader:
        images, labels = images.to(device), labels.to(device)
        optimiser.zero_grad(set_to_none=True)
        loss = F.cross_entropy(model(images), labels)
        loss.backward()
        optimiser.step()
        running_loss += loss.item() * labels.size(0)
        seen += labels.size(0)
    return running_loss / seen


@torch.no_grad()
def evaluate(model, loader, device):
    """Return (accuracy, confusion_matrix) over the whole loader."""
    model.eval()
    confusion = torch.zeros(NUM_CLASSES, NUM_CLASSES, dtype=torch.long)
    correct = 0
    seen = 0
    for images, labels in loader:
        images = images.to(device)
        predictions = model(images).argmax(dim=1).cpu()
        correct += (predictions == labels).sum().item()
        seen += labels.size(0)
        # index = true * NUM_CLASSES + predicted, accumulated in one pass
        flat = labels * NUM_CLASSES + predictions
        confusion += torch.bincount(
            flat, minlength=NUM_CLASSES * NUM_CLASSES
        ).reshape(NUM_CLASSES, NUM_CLASSES)
    return correct / seen, confusion


def format_confusion(confusion):
    """Plain-text confusion matrix — rows are true labels, columns predicted."""
    width = max(6, len(str(int(confusion.max()))) + 2)
    lines = [
        "Confusion matrix — rows are true labels, columns are predictions.",
        "",
        " " * 6 + "".join(f"{c:>{width}}" for c in range(NUM_CLASSES)),
    ]
    for true_label in range(NUM_CLASSES):
        row = "".join(f"{int(v):>{width}}" for v in confusion[true_label])
        lines.append(f"{true_label:>4}  {row}")
    return "\n".join(lines) + "\n"


def parse_args():
    parser = argparse.ArgumentParser(description="ARES MNIST image classification")
    parser.add_argument("--data-dir", required=True,
                        help="Directory holding (or to receive) the MNIST download")
    parser.add_argument("--outdir", required=True,
                        help="Directory for metrics, logs and the trained model")
    parser.add_argument("--epochs", type=int, default=3,
                        help="Number of passes over the training set")
    parser.add_argument("--batch-size", type=int, default=128,
                        help="Images per training batch")
    parser.add_argument("--lr", type=float, default=0.001,
                        help="Adam learning rate")
    parser.add_argument("--workers", type=int, default=2,
                        help="DataLoader worker processes")
    parser.add_argument("--seed", type=int, default=42,
                        help="Random seed, for reproducible accuracy")
    parser.add_argument("--device", choices=["auto", "cuda", "cpu"], default="auto",
                        help="auto falls back to CPU when no GPU is visible")
    return parser.parse_args()


def main():
    args = parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    os.makedirs(args.data_dir, exist_ok=True)

    log = Logger(os.path.join(args.outdir, "training_log.txt"))
    started = time.time()

    try:
        torch.manual_seed(args.seed)
        device = resolve_device(args.device)

        log("========================================")
        log("  ARES — MNIST image classification")
        log("========================================")
        log("")
        log(f"PyTorch     : {torch.__version__}")
        log(f"Device      : {device.type}")
        if device.type == "cuda":
            log(f"GPU         : {torch.cuda.get_device_name(0)}")
        else:
            log("GPU         : none visible — running on CPU")
        log(f"Data dir    : {args.data_dir}")
        log(f"Output dir  : {args.outdir}")
        log(f"Epochs      : {args.epochs}")
        log(f"Batch size  : {args.batch_size}")
        log(f"Learning rate: {args.lr}")
        log("")

        train_loader, test_loader = load_data(
            args.data_dir, args.batch_size, args.workers
        )
        log(f"Train images: {len(train_loader.dataset)}")
        log(f"Test images : {len(test_loader.dataset)}")
        log("")

        model = MnistCNN().to(device)
        parameters = sum(p.numel() for p in model.parameters())
        log(f"Model parameters: {parameters:,}")
        log("")

        optimiser = torch.optim.Adam(model.parameters(), lr=args.lr)

        epochs = []
        for epoch in range(1, args.epochs + 1):
            epoch_started = time.time()
            train_loss = train_one_epoch(model, train_loader, optimiser, device)
            accuracy, confusion = evaluate(model, test_loader, device)
            elapsed = time.time() - epoch_started
            log(f"Epoch {epoch}/{args.epochs}  "
                f"train_loss={train_loss:.4f}  "
                f"test_accuracy={accuracy * 100:.2f}%  "
                f"({elapsed:.1f}s)")
            epochs.append({
                "epoch": epoch,
                "train_loss": round(train_loss, 6),
                "test_accuracy": round(accuracy, 6),
                "seconds": round(elapsed, 2),
            })

        total_seconds = time.time() - started
        final_accuracy = epochs[-1]["test_accuracy"]

        matrix_path = os.path.join(args.outdir, "confusion_matrix.txt")
        with open(matrix_path, "w", encoding="utf-8") as handle:
            handle.write(format_confusion(confusion))

        model_path = os.path.join(args.outdir, "model.pt")
        torch.save(model.state_dict(), model_path)

        metrics = {
            "workflow": "ares-mnist-classification",
            "version": "1.0.0",
            "status": "success",
            "device": device.type,
            "gpu": torch.cuda.get_device_name(0) if device.type == "cuda" else None,
            "torch_version": torch.__version__,
            "parameters": parameters,
            "epochs": epochs,
            "final_test_accuracy": final_accuracy,
            "total_seconds": round(total_seconds, 2),
            "hyperparameters": {
                "epochs": args.epochs,
                "batch_size": args.batch_size,
                "learning_rate": args.lr,
                "seed": args.seed,
            },
        }
        metrics_path = os.path.join(args.outdir, "metrics.json")
        with open(metrics_path, "w", encoding="utf-8") as handle:
            json.dump(metrics, handle, indent=2)
            handle.write("\n")

        log("")
        log(f"Final test accuracy : {final_accuracy * 100:.2f}%")
        log(f"Total time          : {total_seconds:.1f}s")
        log("")
        log("Wrote:")
        for path in (metrics_path, matrix_path, model_path, log.handle.name):
            log(f"  {path}")
        log("")
        log("========================================")
        log("  Complete")
        log("========================================")

    except Exception as error:  # noqa: BLE001 — surface the reason, then fail the job
        log("")
        log(f"FAILED: {type(error).__name__}: {error}")
        log.close()
        raise
    else:
        log.close()


if __name__ == "__main__":
    sys.exit(main())
