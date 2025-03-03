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
include { BCFTOOLS_VIEW  as FILTER    } from '../modules/nf-core/bcftools/view/main.nf'
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

def filterVariants(input_channel, include_only_pass_variants) {
    if (!include_only_pass_variants) {
        return input_channel
    }
    ch_filter_input =  input_channel.map{ meta, vcf -> 
        def tbi = file(vcf + ".tbi")
        tbi.exists() ?
        [meta, vcf, tbi] :
        [meta, vcf, []]
    }
    return FILTER(ch_filter_input, [], [], []).vcf
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

    ch_filter_variants_output = filterVariants(ch_samplesheet, params.include_only_pass_variants)

    ch_preprocessing_input = groupSamples(ch_filter_variants_output)
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
