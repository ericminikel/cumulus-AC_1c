version 1.0

workflow cellranger_aggr {
    input {
        # Aggregate ID
        String aggr_id
        # A comma-separated list of input count result directories (gs urls), note that each directory should contain molecule_info.h5
        String input_counts_directories
        # CellRanger output directory, gs url
        String output_directory

        # Sample normalization MODE: mapped (default), none
        String normalize = "none"
        # Perform secondary analysis (dimensionality reduction, clustering and visualization). Default: false
        Boolean secondary = false
        
        # 7.1.0, 7.0.1, 7.0.0, 6.1.2, 6.1.1, 6.0.2, 6.0.1, 6.0.0, 5.0.1, 5.0.0
        String cellranger_version = "7.1.0"
        # Which docker registry to use: cumulusprod (default) or quay.io/cumulus
        String docker_registry = "quay.io/cumulus"

        # Google cloud zones, default to "us-central1-b", which is consistent with CromWell's genomics.default-zones attribute
        String zones = "us-central1-b"
        # Number of cpus per cellranger job
        Int num_cpu = 64
        # Memory string, e.g. 57.6G
        String memory = "57.6G"
        # Disk space in GB
        Int disk_space = 500

        # Number of preemptible tries
        Int preemptible = 2
        # Backend
        String backend = "gcp"
        # Arn string of AWS queue
        String awsQueueArn = ""
    }

    call run_cellranger_aggr {
        input:
            aggr_id = aggr_id,
            input_counts_directories = input_counts_directories,
            output_directory = sub(output_directory, "/+$", ""),
            normalize = normalize,
            secondary = secondary,
            cellranger_version = cellranger_version,
            docker_registry = docker_registry,
            zones = zones,
            num_cpu = num_cpu,
            memory = memory,
            disk_space = disk_space,
            preemptible = preemptible,
            awsQueueArn = awsQueueArn,
            backend = backend
    }

    output {
        String output_aggr_directory = run_cellranger_aggr.output_aggr_directory
        File output_metrics_summary = run_cellranger_aggr.output_metrics_summary
        File output_web_summary = run_cellranger_aggr.output_web_summary
    }
}

task run_cellranger_aggr {
    input {
        String aggr_id
        String input_counts_directories
        String output_directory
        String normalize
        Boolean secondary
        String cellranger_version
        String docker_registry
        String zones
        Int num_cpu
        String memory
        Int disk_space
        Int preemptible
        String awsQueueArn
        String backend
    }

    command {
        set -e
        export TMPDIR=/tmp
        export BACKEND=~{backend}
        monitor_script.sh > monitoring.log &

        python <<CODE
        import re
        import os
        from subprocess import check_call
        from packaging import version

        counts = []
        with open('aggr.csv', 'w') as fout:
            fout.write('sample_id,molecule_h5\n')
            libs_seen = set()
            current_dir = os.getcwd()
            for i, directory in enumerate('~{input_counts_directories}'.split(',')):
                directory = re.sub('/+$', '', directory) # remove trailing slashes

                sample_id = os.path.basename(directory)
                if sample_id in libs_seen:
                    raise Exception("Found duplicated library id " + sample_id + "!")
                libs_seen.add(sample_id)

                call_args = ['strato', 'cp', '-m', '-r', directory, current_dir]
                print(' '.join(call_args))
                check_call(call_args)
                counts.append(sample_id)
                fout.write(sample_id + "," + current_dir + '/' + sample_id + "/outs/molecule_info.h5\n")

        call_args = ['cellranger', 'aggr', '--id=~{aggr_id}', '--csv=aggr.csv', '--normalize=~{normalize}', '--jobmode=local']
        if '~{secondary}' != 'true':
            call_args.append('--nosecondary')
        print(' '.join(call_args))
        check_call(call_args)
        CODE

        strato sync -m ~{aggr_id} "~{output_directory}/~{aggr_id}"
    }

    output {
        String output_aggr_directory = "~{output_directory}/~{aggr_id}"
        File output_metrics_summary = "~{output_directory}/~{aggr_id}/outs/summary.csv"
        File output_web_summary = "~{output_directory}/~{aggr_id}/outs/web_summary.html"
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
        queueArn: awsQueueArn
    }
}
