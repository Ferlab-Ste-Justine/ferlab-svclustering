/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap            } from 'plugin/nf-validation'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { PREPROCESSING               } from '../modules/local/preprocessing/preprocessing.nf'
include { SVCLUSTERINGDUP             } from '../modules/local/svclustering/svclusteringdup.nf'
include { SVCLUSTERINGDEL             } from '../modules/local/svclustering/svclusteringdel.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SVCLUSTERING {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run your modules
    //
    PREPROCESSING(ch_samplesheet)
    vcfdel = PREPROCESSING.out.vcfdel
    vcfdup = PREPROCESSING.out.vcfdup
    beddel = PREPROCESSING.out.beddel
    beddup = PREPROCESSING.out.beddup
    vcfmod = PREPROCESSING.out.vcfmod
    ploidy = PREPROCESSING.out.ploidy
    ch_versions = ch_versions.mix(PREPROCESSING.out.versions)

    SVCLUSTERINGDUP(
        vcfdup, 
        ploidy,
        params.fasta,
        params.fasta_fai,
        params.fasta_dict,
        )
    ch_versions = ch_versions.mix(SVCLUSTERINGDUP.out.versions)

    SVCLUSTERINGDEL(
        vcfdel, 
        ploidy,
        params.fasta,
        params.fasta_fai,
        params.fasta_dict,
        )
    ch_versions = ch_versions.mix(SVCLUSTERINGDEL.out.versions)

    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
