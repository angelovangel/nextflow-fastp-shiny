# nextflow-fastp-shiny

### Background

This web app is a graphical wrapper for the [nextflow-fastp](https://github.com/angelovangel/nextflow-fastp) pipeline. The pipeline executes [fastp](https://github.com/OpenGene/fastp) on a folder containing fastq files (SE or PE Illumina reads), saves the filtered/trimmed files in results-fastp/fastp_trimmed, and generates a MultiQC report html file (results-fastp/multiqc_report.html). The fastp program is an all-in-one tool for preprocessing FastQ files, similar to FastQC, but much faster and I think better.
The GUI is a [Shiny](https://shiny.rstudio.com/) app, which executes the nextflow pipeline using [processx](https://github.com/r-lib/processx) calls. The pipeline itself retains all the flexibility of nextflow - it can be run in a conda environment or in a docker container, the data can be local or on an Amazon S3 bucket, the executor can be local, PBS, SLURM, AWS Batch...

### Installation

- install nextflow-fastp:

```bash
nextflow pull angelovangel/nextflow-fastp
```

This will install the nextflow-fastp pipeline under `$HOME/.nextflow/assets/angelovangel/nextflow-fastp/`   
In case you have problems using `nextflow pull` due to proxy issues (I have), you can use `git clone` or other methods to install the pipeline so that it is method to 

- install the Shiny app:

```bash
git clone https://github.com/angelovangel/nextflow-fastp-shiny.git

#or, clone and run from within an R session:
shiny::runGitHub('nextflow-fastp-shiny', 'angelovangel')
```

You must be familiar with Shiny server to get the app running. After that, it can be accessed and used via a normal browser.   
*Note:* the fastq folder has to be read-write accessible from the server where the app is running.

### Usage

Select a folder containing fastq files using the `Select fastq folder` button and press `Run nextflow-fastp pipeline`. The Shiny app will show the output of the pipeline and a link to the MultiQC report will be shown in case it finishes without errors. Results are written to the `results-fastp` folder within the fastq folder. The application can be restarted by clicking on the `Reset` button. The log files can be accessed by navigating to the fastq folder and running

```bash
cat .nextflow.log
```

### Demo
![demo](demo/demo.gif)

### Questions

The Shiny app and the nextflow pipeline are written and maintained by [Angel Angelov](https://github.com/angelovangel), if you have questions or problems [open an issue](https://github.com/angelovangel/nextflow-fastp-shiny/issues/new) on github.
