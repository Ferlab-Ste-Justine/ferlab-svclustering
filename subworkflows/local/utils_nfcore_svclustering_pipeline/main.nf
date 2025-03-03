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
========================================================================================
    FUNCTIONS
========================================================================================
*/

/**
* Group tuples based on expected size
*
* Behaves similarly to `groupTuple` operator, but instead of grouping by a key, groups based on an expected size
*
* Transforms a sequence of tuples like (K, V, W, ..) into a sequence of tuples like (list(K), list(V), list(W), ..).
* If there is a remainder, the last tuple will have a smaller list size.
*
* Typically used as preprocessing for local processes executed in batch mode.
*
* Example: 
*   input_ch: Channel.of( [1, 'A'], [2, 'B'], [3, 'C'], [4, 'D'])
*   size: 3
*
*   emitted output: 
*      [[1,2,3], ['A','B','C']]
*      [[4], ['D']]
**/
workflow GROUP_TUPLES_BY_SIZE {
    take: 
        input_ch // Channel: Input channel of tuples
        size     // Integer: Expected size of each tuple group
    main:
        def output_ch = input_ch
            .collate(size)
            .map {tuple_list -> tuple_list.transpose()}
    emit:
        output = output_ch
}

/**
* Transform batch tuples of the form (meta_list, files) into individual (meta, files) tuples
*
* Local processes meant to be run in batch mode emit tuples of the form `(meta_list, files)`,
* where `meta_list` is a list of `meta` dictionaries used to propagate metadata in the workflow.
* This function converts back these batch tuples to standard `(meta, files)` tuples for use in 
* subsequent workflow steps.
*
* Assumes each `meta` dictionary contains a key specifying applicable output file names
* (`output_key` argument). For each `meta`, only the files whose name matches an applicable 
# output file name stored in the meta dictionary will be retained.
* 
* If `remove_output_key` is `true` (default), the key containing the applicable output file names
* will be removed from the meta dictionary.
*/
workflow UNBATCH_META_FILES {
    take: 
        input_ch
        meta_key
        remove_meta_key
    main:
        def output_ch = input_ch
            .flatMap{ meta_list, files -> 
                def file_list = files instanceof List ? files : [files]
                meta_list.collect{ meta -> [meta, file_list]}}
            .map { meta, files ->
                def updated_meta = remove_meta_key?  meta.findAll{it -> it.key != meta_key}: meta
                def applicable_file_suffixes = meta[meta_key]
                def filtered_files = files.findAll{ candidate -> 
                    applicable_file_suffixes.find{ suffix -> candidate.toString().endsWith(suffix)}
                }
                [updated_meta, filtered_files]
            }
    emit:
        output = output_ch
}