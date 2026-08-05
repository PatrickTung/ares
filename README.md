# ARES — AI & Research Execution Stack

Landing page and workflow catalogue for UNSW ResTech research workflows.

**Live site**: https://patricktung.github.io/ares

## Structure

```
ares/
├── index.html                        # Landing page (GitHub Pages root)
├── .nojekyll                         # Empty — disables Jekyll processing
├── assets/
│   └── ares.css                      # Shared styles for workflow detail pages
└── workflows/
    ├── hello-world/                  # Test job — start here
    │   ├── index.html
    │   ├── katana/ares_hello_world.pbs
    │   └── local/run_local.sh, run_local.ps1
    ├── mnist-classification/         # Containerised PyTorch example
    │   ├── index.html
    │   ├── katana/ares_mnist_classification.pbs, prepare.sh
    │   ├── src/train_mnist.py
    │   └── local/run_local.sh, run_local.ps1
    ├── rna-seq-pipeline/index.html
    ├── variant-calling/index.html
    ├── alphafold-batch/index.html
    └── climate-downscaling/index.html
```

Plain static HTML — no build step, no dependencies. The landing page keeps its styles inline; the five workflow detail pages share `assets/ares.css`. The `hello-world` page has its own styles — it's a deliberate variant, not a copy, so don't fold it into the shared sheet.

`hello-world` and `mnist-classification` are the two workflows that ship runnable scripts. `mnist-classification` is the reference for the containerised pattern: the PyTorch image is pulled from Docker Hub with Apptainer at job time and cached under `/srv/scratch/$USER/.ares/containers/`, so nothing has to be installed on Katana. Run its `katana/prepare.sh` on a login node first — it does the container pull and dataset download where the network is reliable, leaving the job able to run offline.

Keep `.nojekyll` in place. Without it, Pages runs Jekyll and would silently drop any future directory beginning with an underscore.

## Local preview

The site is served from the `/ares/` subpath, so preview it that way — serve the **parent** directory:

```
cd ..            # the directory containing ares/
python -m http.server 8000
# open http://localhost:8000/ares/
```

Opening `index.html` directly over `file://` will not reproduce the real base path and will hide broken links.

## Adding a new workflow

1. Create a folder under `workflows/your-workflow-name/`
2. Add `index.html` — copy the RNA-seq example and link `../../assets/ares.css`
3. **Use relative links only** (`../../`, `../../#workflows`). Root-absolute links like `href="/"` resolve outside `/ares/` and 404.
4. Add a card to the workflow grid in `index.html`
5. Push to `main` — GitHub Pages redeploys automatically

## Deployment

GitHub Pages is already configured and deploys from the `main` branch. There is no Actions workflow; pushing to `main` publishes.

## Status

`v0.1-alpha`. The "Run on Katana" buttons currently point at the **development** OnDemand instance (`/pun/dev/OpenComposer/...`) while workflows are being validated. Switch these to `/pun/sys/` at launch.

Two catalogue entries — Cellpose and single-cell RNA-seq — are shown as *Planned* and have no detail page yet.

`mnist-classification` needs its OpenComposer form built before the **Run on Katana** button works; until then the page's "Run it without OnDemand" section is the working path (`prepare.sh` + `qsub`).

## Planned

Not yet implemented, but intended per workflow:

- `main.nf` — Nextflow workflow
- `nextflow.config` — compute profiles
- `params.example.yml` — example parameters
- `ro-crate-metadata.json` — WorkflowHub metadata

## Contact

restech@unsw.edu.au
