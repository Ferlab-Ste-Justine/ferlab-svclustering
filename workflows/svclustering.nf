/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { paramsSummaryMap            } from 'plugin/nf-validation'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { BATCH                       } from '../subworkflows/local/utils_nfcore_svclustering_pipeline/main.nf'
include { UNBATCH                     } from '../subworkflows/local/utils_nfcore_svclustering_pipeline/main.nf'
include { PREPROCESSING               } from '../modules/local/preprocessing/preprocessing.nf'
include { SVCLUSTERINGDUP             } from '../modules/local/svclustering/svclusteringdup.nf'
include { SVCLUSTERINGDEL             } from '../modules/local/svclustering/svclusteringdel.nf'
include { BCFTOOLS_VIEW_BATCH as FILTER_BATCH  } from '../modules/local/bcftools/view_batch/main.nf'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def groupSamples(input_ch){
    return input_ch.map { meta, vcf ->
        def fnum = 1
        [fnum, [meta.familyId] + meta.sample, meta.sample, vcf]
    }
    .groupTuple()  // Group by familyId
}

workflow FILTER_VARIANTS {
    take:
    ch_input
    include_only_pass_variants
    batch_size

    main:
    def ch_output = ch_input
    def ch_versions = Channel.empty()
    if(include_only_pass_variants) {
        def ch_input_with_index =  ch_input.map{ meta, vcf ->
            [meta, vcf, file(vcf + ".tbi")]
        }
        BATCH(ch_input_with_index, batch_size, "filter")        
        FILTER_BATCH(BATCH.out.output, [], [], [])
        UNBATCH(FILTER_BATCH.out.vcf)

        ch_output = UNBATCH.output
        ch_versions = ch_versions.mix(FILTER_BATCH.out.versions)
    }

    emit:
    output = ch_output
    versions = ch_versions
}


workflow SVCLUSTERING {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    //
    // MODULE: Run your modules
    //

    FILTER_VARIANTS(
        ch_samplesheet, 
        params.include_only_pass_variants,
        params.filter_batch_size
    )
    ch_versions = ch_versions.mix(FILTER_VARIANTS.out.versions)

    ch_preprocessing_input = groupSamples(FILTER_VARIANTS.out.output)
    PREPROCESSING(ch_preprocessing_input)
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
        file(params.fasta),
        file(params.fasta_fai),
        file(params.fasta_dict),
        )
    ch_versions = ch_versions.mix(SVCLUSTERINGDUP.out.versions)

    SVCLUSTERINGDEL(
        vcfdel, 
        ploidy,
        file(params.fasta),
        file(params.fasta_fai),
        file(params.fasta_dict),
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
