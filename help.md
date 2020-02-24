### Background

This web app is a graphical wrapper for the [nextflow-fastp](https://github.com/angelovangel/nextflow-fastp) pipeline. The pipeline executes [fastp](https://github.com/OpenGene/fastp) on a folder containing fastq files (SE or PE Illumina reads), saves the filtered/trimmed files in results/fastp_trimmed, and generates a MultiQC report html file (results/multiqc_report.html). The fastp program is a all-in-one tool for preprocessing FastQ files, similar to FastQC, but much faster a I think better.
The GUI is a [Shiny]() app, which executes the nextflow pipeline using [processx](https://github.com/r-lib/processx) calls. The pipeline itself retains all the flexibility of nextflow - it can be run in a conda environment or in a docker container, the data can be local or on an Amazon S3 bucket, the executor can be local, PBS, SLURM, AWS Batch...   
A test run with a small fastq dataset can be executed by selecting `profile -- test`.

### Installation


### Usage

Select a folder containing fastq files using the `fastq_folder` button and press `Run nextflow-fastp pipeline`. The Shiny app can be restarted by clicking on the green title 'nextflow-fastp' on the top left. Results are written to the `date-results` folder within the fastq folder, the log files can be accessed by navigating to the fastq folder and running

```bash
cat .nextflow.log
```

### Questions

The Shiny app and the nextflow pipeline are written and maintained by [Angel Angelov](https://github.com/angelovangel), mail your questions to aangeloo@gmail.com
