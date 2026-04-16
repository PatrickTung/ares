# ARES — AI & Research Execution Stack

Landing page and workflow catalogue for UNSW ResTech research workflows.

**Live site**: https://[your-username].github.io/ares

## Structure

```
ares/
├── index.html                        # Main landing page (GitHub Pages root)
├── workflows/
│   ├── rna-seq-pipeline/
│   │   ├── index.html                # Workflow detail page
│   │   ├── main.nf                   # Nextflow workflow
│   │   ├── nextflow.config           # Compute profiles
│   │   ├── params.example.yml        # Example parameters
│   │   └── ro-crate-metadata.json    # WorkflowHub metadata
│   └── [other-workflows]/
└── .github/
    └── workflows/
        └── deploy.yml                # Auto-deploy to GitHub Pages
```

## Adding a new workflow

1. Create a folder under `workflows/your-workflow-name/`
2. Add `index.html` (copy and edit the RNA-seq example)
3. Add the workflow files (`main.nf`, `nextflow.config`, etc.)
4. Add a card to `index.html` in the workflow grid
5. Push to `main` — GitHub Actions deploys automatically

## Setting up GitHub Pages

1. Go to repo **Settings → Pages**
2. Set source to **GitHub Actions**
3. Push any commit to trigger the first deploy

## Contact

restech@unsw.edu.au
