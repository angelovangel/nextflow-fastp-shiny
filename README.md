# nextflow-fastp-shiny

### Background

This is a graphical user interface for the [nextflow-fastp](https://github.com/angelovangel/nextflow-fastp) pipeline. 
The GUI is a [Shiny](https://shiny.rstudio.com/) app, which executes the underlying nextflow pipeline using [processx](https://github.com/r-lib/processx) calls. The pipeline itself retains all the flexibility of nextflow - it can be run in a conda environment or in a docker container, the data can be local or on an Amazon S3 bucket, the executor can be local, PBS, SLURM, AWS Batch...

### Installation

All that is needed is [nextflow](http://nextflow.io) and this shiny app. When the app is started for the first time, the angelovangel/nextflow-fastp pipeline is pulled from github and will be available under `$HOME/.nextflow/assets/angelovangel/nextflow-fastp/`. 

To install the Shiny app:

```bash
git clone https://github.com/angelovangel/nextflow-fastp-shiny.git

#or, run directly from within an R session:
shiny::runGitHub('nextflow-fastp-shiny', 'angelovangel')
```

*Note:* the fastq folder has to be read-write accessible from the server where the app is running.

### Usage

Select a folder containing fastq files using the `Select fastq folder` button and press `Run nextflow-fastp pipeline`. Results are written to the `results-fastp` folder within the fastq folder. The log files can be accessed by navigating to the fastq folder and running

```bash
cat .nextflow.log
```

### Demo
![demo](demo/demo.gif)

### Questions

The Shiny app and the nextflow pipeline are written and maintained by [Angel Angelov](https://github.com/angelovangel), if you have questions or problems [open an issue](https://github.com/angelovangel/nextflow-fastp-shiny/issues/new) on github.
