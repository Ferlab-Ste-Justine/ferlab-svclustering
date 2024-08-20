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
    python ${moduleDir}/resources/usr/bin/sample_preprocessing.py --sample_id $sample_ids --path $vcf_paths

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sample_preprocessing.py: \$(python ${moduleDir}/resources/usr/bin/sample_preprocessing.py --version | sed 's/sample_preprocessing.py version//')
    END_VERSIONS
    
    """
    
}
