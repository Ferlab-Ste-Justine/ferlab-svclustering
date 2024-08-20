process SVCLUSTERINGDUP {
    tag "Svclustering_duplicates"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::gatk4=4.5.0.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gatk4:4.5.0.0--py36hdfd78af_0':
        'biocontainers/gatk4:4.5.0.0--py36hdfd78af_0' }"

    input:
    path(vcfdup)
    path(ploidy)
    path(fasta)
    path(fai)
    path(fasta_dict)
    
    output:
    path("*.vcf.gz"),     emit: familydup
    path "versions.yml",  emit: versions

    script:
    def dups = vcfdup.join(' -V ')
    """
    gatk SVCluster --output ALL.MAX_CLIQUE_RO80.DUP.vcf.gz -V $dups \
     --ploidy-table $ploidy --algorithm MAX_CLIQUE \
     --reference $fasta --depth-interval-overlap 0.8 \
     --breakpoint-summary-strategy MIN_START_MAX_END

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gatk4: \$(echo \$(gatk --version 2>&1) | sed 's/^.*(GATK) v//; s/ .*\$//')
    END_VERSIONS
   """
}
