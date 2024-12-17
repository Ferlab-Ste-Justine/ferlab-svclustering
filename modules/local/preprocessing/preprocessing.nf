process PREPROCESSING {
    tag "Preprocessing"
    label 'process_low'
 
    conda (params.enable_conda ? "bioconda::python-nextflow=0.8" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python-nextflow:0.8--pyhdfd78af_0':
        'biocontainers/python-nextflow:0.8--pyhdfd78af_0' }"

    input: 
    tuple val(num), val(familyId), val(samples), path(vcfs)

    output:
    path("*.DEL.vcf"),        emit: vcfdel
    path("*.DUP.vcf"),        emit: vcfdup
    path("*.DEL.bed"),        emit: beddel
    path("*.DUP.bed"),        emit: beddup
    path("*.mod.vcf"),        emit: vcfmod
    path "ploidy-table.tsv",  emit: ploidy
    path "versions.yml",      emit: versions 
        
    script:
    def sample_ids = samples.join(' ')
    def vcf_paths  = vcfs.join(' ')
    """
    sample_preprocessing.py --sample_id $sample_ids --path $vcf_paths

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sample_preprocessing.py: \$(sample_preprocessing.py --version | sed 's/sample_preprocessing.py version//')
    END_VERSIONS
    
    """

    stub:
    def sample_ids = samples.join(' ')
    def vcf_paths  = vcfs.join(' ') 
    """
    # To make this stub realist, we verify that the input vcf paths exists
    for vcf_path in $vcf_paths; do
        if [ ! -f \$vcf_path ]; then
            echo "ERROR: VCF file \$vcf_path does not exist"
            exit 1
        fi
    done

    # Create empty output files
    for sample_id in $sample_ids; do
        touch \${sample_id}.cnv.mod.DEL.bed
        touch \${sample_id}.cnv.mod.DEL.vcf
        touch \${sample_id}.cnv.mod.DUP.bed
        touch \${sample_id}.cnv.mod.DUP.vcf
        touch \${sample_id}.cnv.mod.vcf
    done
    touch ploidy-table.tsv

    # Create version file as the main script does
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sample_preprocessing.py: stub
    END_VERSIONS
    """

}
