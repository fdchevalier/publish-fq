# publish-fq

The aim of this project is (i) to publish fastq files generated by [bcl2fastq](https://support.illumina.com/sequencing/sequencing_software/bcl2fastq-conversion-software.html) the same way it used to be in our institute with the no longer supported Casava pipeline and our internal publishing scripts (referred as the "old Casava way") and (ii) to add new functionalities for tractability and communication. More details are available in the [documentation](Documentation/publish-fq.pdf).

This project is primarily designed for internal use by our sequencing facility at [Texas Biomedical Research Institute](https://www.txbiomed.org/) but feel free to fork and adapt to your needs.

## Prerequisites

To run the script properly, you need a folder containing the fastq files generated with bcl2fastq and the corresponding samplesheet.

## Files

The files available are:
* `publish-fq.sh`: the script which reorganizes output in folders either by samples or projects,
* `email_template.txt`: the template for sending emails when publishing is done,
* `Documentation/publish-fq.pdf`: the documentation related to the above files.

Details about these files are available in the [documentation](Documentation/publish-fq.pdf).

## Installation

To download the latest version of the files:
```
git clone https://github.com/fdchevalier/myscreen
```

For convenience, the script should be accessible system-wide by either including the folder in your `$PATH` or by moving the script in a folder present in your path (e.g. `$HOME/local/bin/`). The email template must be in the same directory as the script.

Details about installation are available in the [documentation](Documentation/publish-fq.pdf).

## Usage

A summary of available options can be obtained using `./publish-fq.sh -h`.

Details about usage are available in the [documentation](Documentation/publish-fq.pdf).

## License

This project is licensed under the [GPLv3](LICENSE).

