process SVCLUSTERINGDEL {
    tag "Svclustering_deletions"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::gatk4=4.5.0.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.5.0.0--py36hdfd78af_0':
        'biocontainers/gatk4:4.5.0.0--py36hdfd78af_0' }"

    input:
    path(vcfdel)
    path(ploidy)
    path(fasta)
    path(fai)
    path(fasta_dict)
    
    
    output:
    path("*.vcf.gz")   , emit: alldel
    path "versions.yml", emit: versions
   
    script:
    def args                 = task.ext.args ?: ''
    def dels                 = vcfdel.join(' -V ')
    def clustering_algorithm = params.clustering_algorithm
    def overlap              = params.overlap
    def breakpoint_strategy  = params.breakpoint_strategy
    def output_file          = "ALL.${clustering_algorithm.toUpperCase()}_RO${Math.round(overlap * 100)}.DEL.vcf.gz"
    """
    gatk SVCluster --output $output_file -V $dels \
     --ploidy-table $ploidy --algorithm $clustering_algorithm \
     --reference $fasta --depth-interval-overlap $overlap \
     --breakpoint-summary-strategy $breakpoint_strategy \
     $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def dels = vcfdel.join(' ')
    def clustering_algorithm = params.clustering_algorithm
    def overlap              = params.overlap
    def output_file          = "ALL.${clustering_algorithm.toUpperCase()}_RO${Math.round(overlap * 100)}.DEL.vcf.gz"
    """
    # To make this stub realist, we verify that the input file exists
    for input_file in $dels $fasta $ploidy; do
        if [ ! -f \$input_file ]; then
            echo "ERROR: file \$input_file does not exist"
            exit 1
        fi
    done
    
    # Create empty output file
    touch ${output_file}

    # Create version file as the main script does
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
    """
}
