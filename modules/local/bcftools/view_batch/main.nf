// Using a local module because we did not find an equivalent in the nf-core modules
// It is strongly inspired by the nfcore bcftools/view module.
process BCFTOOLS_VIEW_BATCH {
    tag "${meta instanceof List ? meta[0].id : meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta), path(vcf), path(index)
    path(regions)
    path(targets)
    path(samples)

    output:
    tuple val(meta), path("*.{vcf,vcf.gz,bcf,bcf.gz}"), emit: vcf
    tuple val(meta), path("*.tbi")                    , emit: tbi, optional: true
    tuple val(meta), path("*.csi")                    , emit: csi, optional: true
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def meta_list = meta instanceof List ? meta : [meta]
    def input_vcf_list = vcf instanceof List ? vcf : [vcf]

    def prefix_key = task.ext.prefix_key ?: "prefix"
    def args = task.ext.args ?: ''
    def output_vcf_list = getOutputVcfFiles(meta_list, prefix_key, args)

    def regions_file  = regions ? "--regions-file ${regions}" : ""
    def targets_file = targets ? "--targets-file ${targets}" : ""
    def samples_file =  samples ? "--samples-file ${samples}" : ""

    """
    #!/bin/bash
    set -e

    # Initialize arrays
    input_vcfs=(${input_vcf_list.join(" ")})
    output_vcfs=(${output_vcf_list.join(" ")})

    # Loop over prefixes and vcf files
    for i in \${!input_vcfs[@]}; do
        input_file=\${input_vcfs[\$i]}
        output_file=\${output_vcfs[\$i]}

        bcftools view \\
            --output \${output_file} \\
            ${regions_file} \\
            ${targets_file} \\
            ${samples_file} \\
            $args \\
            --threads $task.cpus \\
            \${input_file}
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def meta_list = meta instanceof List ? meta : [meta]
    def prefix_key = task.ext.prefix_key ?: "prefix"
    def args = task.ext.args ?: ''
    def output_vcf_list = getOutputVcfFiles(meta_list, prefix_key, args)
    def indexExtension = getIndexExtension(args)

    def regions_file  = regions ? "--regions-file ${regions}" : ""
    def targets_file = targets ? "--targets-file ${targets}" : ""
    def samples_file =  samples ? "--samples-file ${samples}" : ""
    
    """
    #!/bin/bash
    set -e

    # Initialize arrays
    output_vcfs=(${output_vcf_list.join(" ")})

    # Loop over prefixes
    for i in \${!output_vcfs[@]}; do
        output_file=\${output_vcfs[\$i]}
        touch \${output_file}
        ${indexExtension ? "touch \${output_file}.${indexExtension}" : ""}
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}

def getOutputVcfFiles(meta_list, prefix_key, args){
    def extension = getExtension(args)
    return meta_list.collect{
        m -> "${m[prefix_key]}.${extension}"
    }
}

def getExtension(args){
    return args.contains("--output-type b") || args.contains("-Ob") ? "bcf.gz" :
        args.contains("--output-type u") || args.contains("-Ou") ? "bcf" :
        args.contains("--output-type z") || args.contains("-Oz") ? "vcf.gz" :
        args.contains("--output-type v") || args.contains("-Ov") ? "vcf" :
        "vcf"
}

def getIndexExtension(args){
    return args.contains("--write-index=tbi") || args.contains("-W=tbi") ? "tbi" :
        args.contains("--write-index=csi") || args.contains("-W=csi") ? "csi" :
        args.contains("--write-index") || args.contains("-W") ? "csi" :
        ""
}