// Using a local module because we did not find an equivalent in the nf-core modules
// It is strongly inspired by it's nf-core non-batch equivalent BCFTOOLS_VIEW
process BCFTOOLS_VIEW_BATCH {
    tag "${meta_list[0].id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.20--h8b25389_0':
        'biocontainers/bcftools:1.20--h8b25389_0' }"

    input:
    tuple val(meta_list), path(vcf_list), path(index_list)
    val(meta_output_key)
    path(regions)
    path(targets)
    path(samples)

    output:
    tuple val(meta_list), path("*.{vcf,vcf.gz,bcf,bcf.gz}"), emit: vcf
    tuple val(meta_list), path("*.tbi")                    , emit: tbi, optional: true
    tuple val(meta_list), path("*.csi")                    , emit: csi, optional: true
    path "versions.yml"                               , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefixes = task.ext.prefixes?: getDefaultPrefixes(meta_list)
    def regions_file  = regions ? "--regions-file ${regions}" : ""
    def targets_file = targets ? "--targets-file ${targets}" : ""
    def samples_file =  samples ? "--samples-file ${samples}" : ""
    def extension = getExtension(args)
    def indexExtension = getIndexExtension(args)

    // Store output file names in meta dictionaries
    update_metas(meta_list, prefixes, extension, indexExtension, meta_output_key)
    """
    #!/bin/bash

    # Initialize arrays
    prefixes=(${prefixes.join(" ")})
    vcf=(${vcf_list.join(" ")})

    # Loop over prefixes and vcf files
    for i in \${!prefixes[@]}; do
        prefix=\${prefixes[\$i]}
        vcf_file=\${vcf[\$i]}

        bcftools view \\
            --output \${prefix}.${extension} \\
            ${regions_file} \\
            ${targets_file} \\
            ${samples_file} \\
            $args \\
            --threads $task.cpus \\
            \${vcf_file}
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefixes = task.ext.prefixes?: getDefaultPrefixes(meta_list)
    def extension = getExtension(args)
    def indexExtension = getIndexExtension(args)

    // Store output file names in meta dictionaries
    update_metas(meta_list, prefixes, extension, indexExtension, meta_output_key)
    
    """
    #!/bin/bash

    # Initialize arrays
    prefixes=(${prefixes.join(" ")})

    # Loop over prefixes
    for i in \${!prefixes[@]}; do
        prefix=\${prefixes[\$i]}
        touch \${prefix}.${extension}
        ${indexExtension ? "touch \${prefix}.${extension}.${indexExtension}" : ""}
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}


def getDefaultPrefixes(meta_list){
    return meta_list.collect{meta ->  "viewed.${meta.id}"}
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

def update_metas(meta_list, prefixes, extension, indexExtension, meta_key) {
    meta_list.eachWithIndex { meta, idx -> 
        def out_files = ["${prefixes[idx]}.${extension}"]
        if (indexExtension) {
            out_files += "${prefixes[idx]}.${extension}.${indexExtension}"
        }
        meta[meta_key] = out_files
    }
}