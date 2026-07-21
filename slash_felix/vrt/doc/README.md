# VRT Documentation Generation

This folder shows how to generate the documentation for the VRT project.

## Dependencies

The documentation generation process has the following dependencies:

- doxygen
- texlive-latex-base
- texlive-latex-extra
- texlive-latex-recommended

To install, run:

```bash 
sudo apt install doxygen texlive-latex-base texlive-latex-extra texlive-latex-recommended
```

## How to run

To run the documentation generation process, run one of the following commands, based on what type of documentation you want to generate.

| Command |	Description |
|----|----------|
| make |	Generate both HTML and PDF documentation (default) |
| make html|	Generate HTML documentation only |
| make pdf|	Generate PDF documentation (requires LaTeX) |
| make clean|	Remove all generated documentation files |
| make rebuild|	Clean and regenerate all documentation from scratch |
| make help|	Display help information about available commands |