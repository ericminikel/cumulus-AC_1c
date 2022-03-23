version 1.0

workflow cellranger_mkfastq {
    input {
        # Input BCL directory, gs url
        String input_bcl_directory
        # 3 column CSV file (Lane, Sample, Index)
        File input_csv_file
        # CellRanger output directory, gs url
        String output_directory

        # Whether to delete input bcl directory. If false, you should delete this folder yourself so as to not incur storage charges.
        Boolean delete_input_bcl_directory = false
        # Number of allowed mismatches per index
        Int? barcode_mismatches
        # Only demultiplex samples identified by an i7-only sample index, ignoring dual-indexed samples. Dual-indexed samples will not be demultiplexed.
        Boolean filter_single_index = false
        # Override the read lengths as specified in RunInfo.xml
        String? use_bases_mask
        # Delete undetermined FASTQ files generated by bcl2fastq2
        Boolean delete_undetermined = false

        # cellranger version
        String cellranger_version
        # Which docker registry to use
        String docker_registry

        # Google cloud zones, default to "us-central1-b", which is consistent with CromWell's genomics.default-zones attribute
        String zones = "us-central1-b"
        # Number of cpus per cellranger job
        Int num_cpu = 32
        # Memory string, e.g. 120G
        String memory = "120G"
        # Disk space in GB
        Int disk_space = 1500
        # Number of preemptible tries
        Int preemptible = 2
        # Max number of retries for AWS instance
        Int awsMaxRetries = 5
        # Backend
        String backend = "gcp"
        # Arn string of AWS queue
        String awsQueueArn = ""
    }

    call run_cellranger_mkfastq {
        input:
            input_bcl_directory = sub(input_bcl_directory, "/+$", ""),
            input_csv_file = input_csv_file,
            output_directory = sub(output_directory, "/+$", ""),
            delete_input_bcl_directory = delete_input_bcl_directory,
            barcode_mismatches = barcode_mismatches,
            filter_single_index = filter_single_index,
            use_bases_mask = use_bases_mask,
            delete_undetermined = delete_undetermined,
            cellranger_version = cellranger_version,
            docker_registry = docker_registry,
            zones = zones,
            num_cpu = num_cpu,
            memory = memory,
            disk_space = disk_space,
            preemptible = preemptible,
            awsMaxRetries = awsMaxRetries,
            backend = backend,
            awsQueueArn = awsQueueArn
    }

    output {
        String output_fastqs_directory = run_cellranger_mkfastq.output_fastqs_directory
        String output_fastqs_flowcell_directory = run_cellranger_mkfastq.output_fastqs_flowcell_directory
        File monitoringLog = run_cellranger_mkfastq.monitoringLog
    }
}

task run_cellranger_mkfastq {
    input {
        String input_bcl_directory
        File input_csv_file
        String output_directory
        Boolean delete_input_bcl_directory
        Int? barcode_mismatches
        Boolean filter_single_index
        String? use_bases_mask
        Boolean delete_undetermined
        String cellranger_version
        String docker_registry
        String zones
        Int num_cpu
        String memory
        Int disk_space
        Int preemptible
        Int awsMaxRetries
        String backend
        String awsQueueArn
    }

    String run_id = basename(input_bcl_directory)

    command {
        set -e
        export TMPDIR=/tmp
        monitor_script.sh > monitoring.log &
        strato sync --backend "~{backend}" -m ~{input_bcl_directory} ~{run_id}

        python <<CODE
        import os
        import glob
        import sys
        import pandas as pd
        import subprocess

        mkfastq_args = ['cellranger', 'mkfastq', '--id=results', '--run=~{run_id}', '--csv=~{input_csv_file}', '--jobmode=local']
        barcode_mismatches = '~{barcode_mismatches}'
        if barcode_mismatches != '':
            mkfastq_args += ['--barcode-mismatches', barcode_mismatches]
        if '~{filter_single_index}' == 'true':
            mkfastq_args.append('--filter-single-index')
        if '~{use_bases_mask}' != '':
            mkfastq_args.extend(['--use-bases-mask', '~{use_bases_mask}'])
        if '~{delete_undetermined}' == 'true':
            mkfastq_args.append('--delete-undetermined')
        p = subprocess.run(mkfastq_args)

        if p.returncode != 0: # ./MAKE_FASTQS_CS/MAKE_FASTQS/BCL2FASTQ_WITH_SAMPLESHEET/fork0/chnk0-u8d92d5526b/_stderr
            if os.path.exists('results/MAKE_FASTQS_CS/MAKE_FASTQS/BCL2FASTQ_WITH_SAMPLESHEET/fork0/'):
                output_dirs = os.listdir('results/MAKE_FASTQS_CS/MAKE_FASTQS/BCL2FASTQ_WITH_SAMPLESHEET/fork0/')
                for output in output_dirs:
                    if output.startswith('chnk0-'):
                        break
                with open(os.path.join('results/MAKE_FASTQS_CS/MAKE_FASTQS/BCL2FASTQ_WITH_SAMPLESHEET/fork0/', output, '_stderr'), "r") as error_in:
                    for line in error_in:
                        print(line, file=sys.stderr)
            sys.exit(1)

        with open("output_fastqs_flowcell_directory.txt", "w") as fout:
            flowcell = [name for name in os.listdir('results/outs/fastq_path') if name != 'Reports' and name != 'Stats' and os.path.isdir('results/outs/fastq_path/' + name)][0]
            fout.write('~{output_directory}/~{run_id}_fastqs/fastq_path/' + flowcell + '\n')

        CODE

        strato sync --backend "~{backend}" -m results/outs "~{output_directory}/~{run_id}_fastqs"

        python <<CODE
        from subprocess import check_call, check_output, CalledProcessError
        if '~{delete_input_bcl_directory}' is 'true':
            try:
                call_args = ['strato', 'exists', '--backend', '~{backend}', '~{output_directory}/~{run_id}_fastqs/input_samplesheet.csv']
                print(' '.join(call_args))
                check_output(call_args)
                call_args = ['strato', 'rm', '--backend', '~{backend}', '-m', '-r', '~{input_bcl_directory}']
                print(' '.join(call_args))
                check_call(call_args)
                print('~{input_bcl_directory} is deleted!')
            except CalledProcessError:
                print("Failed to delete BCL directory.")
        CODE
    }

    output {
        String output_fastqs_directory = "~{output_directory}/~{run_id}_fastqs"
        String output_fastqs_flowcell_directory = read_lines("output_fastqs_flowcell_directory.txt")[0]
        File monitoringLog = "monitoring.log"
    }

    runtime {
        docker: "~{docker_registry}/cellranger:~{cellranger_version}"
        zones: zones
        memory: memory
        bootDiskSizeGb: 12
        disks: "local-disk ~{disk_space} HDD"
        cpu: num_cpu
        preemptible: preemptible
        maxRetries: if backend == "aws" then awsMaxRetries else 0
        queueArn: awsQueueArn
    }
}
