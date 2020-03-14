### nextflow-fastp-shiny

This web app is a graphical interface for the [nextflow-fastp](https://github.com/angelovangel/nextflow-fastp) pipeline. The app executes [fastp](https://github.com/OpenGene/fastp) on a folder containing fastq files (SE or PE Illumina reads), saves the filtered/trimmed files and generates a MultiQC report. The fastp program is an all-in-one tool for preprocessing FastQ files, similar to FastQC, but much faster and I think better.

### Usage

 Select a folder containing fastq files using the `Select fastq folder` button and press `Run nextflow-fastp pipeline`.

- Results are written to the `results-fastp` folder within the fastq folder
- You can always restart the app by clicking on the nextflow-fastp title
- You can start the run with Nextflow Tower, then go to the provided url and monitor it there!

The nextflow log files can be accessed by navigating to the fastq folder and running

```bash
cat .nextflow.log
```

### Questions

The Shiny app and the nextflow pipeline are written and maintained by [Angel Angelov](https://github.com/angelovangel), if you have questions or problems [open an issue](https://github.com/angelovangel/nextflow-fastp-shiny/issues/new) on github.
