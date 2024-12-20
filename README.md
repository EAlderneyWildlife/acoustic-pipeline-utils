# Utilities for the Acoustic Pipeline
This repo collects utility scripts for use with the BTO's Acoustic Pipeline.

## Contents
### File chunking script
This script chunks data up into subfolders based on a desired folder size. As the Acoustic Pipeline charges one credit per GB uploaded, it chunks to just below the GB threshold to minimise the chance of any wasted credits. 

Currently it chunks to 8.97 GB folders, which is a folder size that readily uploads without lagging. An alternative approach could be to allow a user input for the desired folder size.

## Roadmap
- [ ] More helpful reporting with file movement, or a functional progress bar.