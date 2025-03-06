//
// Subworkflow with functionality specific to the ferlab/svclustering pipeline
//

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UTILS_NFVALIDATION_PLUGIN } from '../../nf-core/utils_nfvalidation_plugin'
include { paramsSummaryMap          } from 'plugin/nf-validation'
include { fromSamplesheet           } from 'plugin/nf-validation'
include { UTILS_NEXTFLOW_PIPELINE   } from '../../nf-core/utils_nextflow_pipeline'
include { completionEmail           } from '../../nf-core/utils_nfcore_pipeline'
include { completionSummary         } from '../../nf-core/utils_nfcore_pipeline'
include { dashedLine                } from '../../nf-core/utils_nfcore_pipeline'
include { nfCoreLogo                } from '../../nf-core/utils_nfcore_pipeline'
include { imNotification            } from '../../nf-core/utils_nfcore_pipeline'
include { UTILS_NFCORE_PIPELINE     } from '../../nf-core/utils_nfcore_pipeline'
include { workflowCitation          } from '../../nf-core/utils_nfcore_pipeline'

/*
========================================================================================
    SUBWORKFLOW TO INITIALISE PIPELINE
========================================================================================
*/

workflow PIPELINE_INITIALISATION {

    take:
    version           // boolean: Display version and exit
    help              // boolean: Display help text
    validate_params   // boolean: Boolean whether to validate parameters against the schema at runtime
    monochrome_logs   // boolean: Do not use coloured log outputs
    nextflow_cli_args //   array: List of positional nextflow CLI args
    outdir            //  string: The output directory where the results will be saved
    input             //  string: Path to input samplesheet

    main:

    ch_versions = Channel.empty()

    //
    // Print version and exit if required and dump pipeline parameters to JSON file
    //
    UTILS_NEXTFLOW_PIPELINE (
        version,
        true,
        outdir,
        workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1
    )

    //
    // Validate parameters and generate parameter summary to stdout
    //
    pre_help_text = nfCoreLogo(monochrome_logs)
    post_help_text = '\n' + workflowCitation() + '\n' + dashedLine(monochrome_logs)
    def String workflow_command = "nextflow run ${workflow.manifest.name} -profile <docker/singularity/.../institute> --input samplesheet.csv --outdir <OUTDIR>"
    UTILS_NFVALIDATION_PLUGIN (
        help,
        workflow_command,
        pre_help_text,
        post_help_text,
        validate_params,
        "nextflow_schema.json"
    )

    //
    // Check config provided to the pipeline
    //
    UTILS_NFCORE_PIPELINE (
        nextflow_cli_args
    )

    //
    // Create channel from input file provided through params.input
    Channel
    .fromSamplesheet("input")
    // .view()
    .set { ch_samplesheet }
  
    emit:
    samplesheet = ch_samplesheet
    versions    = ch_versions
}

/*
========================================================================================
    SUBWORKFLOW FOR PIPELINE COMPLETION
========================================================================================
*/

workflow PIPELINE_COMPLETION {

    take:
    outdir          //    path: Path to output directory where results will be published
    monochrome_logs // boolean: Disable ANSI colour codes in log output


    main:

    summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    workflow.onError {
        log.error "Pipeline failed. Please refer to troubleshooting docs: https://nf-co.re/docs/usage/troubleshooting"
    }
}

/*
===========================================================================================
    REUSABLE SUBWORKFLOWS
===========================================================================================
*/

/**
*  Subworkflow to modify an input channel for batch mode.
*
*  Takes as input a channel of tuples conforming to the meta dictionary pattern,
*  where the first element of the tuple (typically called "meta") is a dictionary 
*  containing metadata information.
*
*  Batches tuples together based on the size parameter and emits a channel of batched tuples. 
*  More precisely, transforms a sequence of tuples like `(meta, V, W, ...)` into a sequence of 
*  tuples like `(list(meta), list(V), list(W), ...)`.
*  If there is a remainder, the last batch tuple will have a smaller list size.
*
*  The meta dictionary is updated to include a prefix key, will will be used for the 
*  output files produced by the batched process. The prefix key is set to 
*  "sample_${meta.sample}.${tag}".
**/
workflow BATCH {
    take: 
        input_ch // Channel: Input channel of tuples, with the first element of the tuple being the meta dictionary
        size     // Integer: Expected size of the batch
        tag      // Tag to be added to the output files prefixes
    main:
        def output_ch = input_ch
            .map{ it ->
                def updated_meta = it[0] + [prefix: "sample_${it[0].sample}.${tag}"]
                [updated_meta] + it[1..-1]
            }
            .collate(size)
            .map {tuple_list -> tuple_list.transpose()}
    emit:
        output = output_ch
}

/**
* Transform batch tuples of the form (meta_list, files) into individual (meta, files) tuples
*
* Local processes running in batch mode emit tuples of the form `(meta_list, files)`,
* where `meta_list` is a list of `meta` dictionaries used to propagate metadata in the workflow.
* This function converts back these batch tuples to standard `(meta, files)` tuples for use in 
* subsequent workflow steps.
*
* Assumes each `meta` dictionary contains a key called 'prefix' that holds the prefix of the
* applicable output files for the sample. If there is only one output file matching a sample,
* it is emitted as an individual file instead of a list with one element.
*
* The `prefix` key is removed from the `meta` dictionary to avoid pollution.
**/
workflow UNBATCH {
    take: 
        input_ch
    main:
        def output_ch = input_ch
            .flatMap{ meta_list, files -> 
                def file_list = files instanceof List ? files : [files]
                meta_list.collect{ meta -> [meta, file_list]}}
            .map { meta, files ->
                def updated_meta = meta.findAll{it -> it.key != "prefix"}
                def prefix = meta["prefix"]
                def filtered_files = files.findAll{ candidate -> candidate.name.startsWith(prefix)}
                [updated_meta, filtered_files]
            }
            .map {meta, files ->
                [meta, files.size() == 1 ? files[0] : files]
            }
    emit:
        output = output_ch
}


/*
========================================================================================
    FUNCTIONS
========================================================================================
*/