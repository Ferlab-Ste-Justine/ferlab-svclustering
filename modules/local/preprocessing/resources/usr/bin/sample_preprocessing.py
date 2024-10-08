#!/usr/bin/env python3

import argparse
import gzip
import os
import re
import sys

VERSION = "1.0"

def create_ploidy_table(samples):
    """
    Creates a ploidy table with chromosome names and sample IDs.

    Args:
        samples (list): List of tuples containing sample_id and vcf_path.
    """
    with open("ploidy-table.tsv", "w") as f:
        # Write header with chromosome names
        chroms = ["chr{}".format(chr) for chr in range(1, 23)] + ["chrX", "chrY"]
        f.write("SAMPLE\t{}\n".format("\t".join(chroms)))

        # Write ploidy information for each sample
        for sample_id, _ in samples:
            ploidy_values = "\t".join(["2"] * len(chroms))
            f.write("{}\t{}\n".format(sample_id, ploidy_values))

def process_vcf(sample_id, vcf_path):
    """
    Processes the CNV VCF file for a given sample.

    Args:
        sample_id (str): The sample ID.
        vcf_path (str): The path to the VCF file.
    """
    input_vcf = vcf_path
    mod_vcf = f"{sample_id}.cnv.mod.vcf"
    dup_vcf = f"{sample_id}.cnv.mod.DUP.vcf"
    del_vcf = f"{sample_id}.cnv.mod.DEL.vcf"

    # Modify the VCF content
    with gzip.open(input_vcf, 'rt') if input_vcf.endswith('.gz') else open(input_vcf, 'r') as infile, open(mod_vcf, 'w') as outfile:
        for line in infile:
            if line.startswith("##FORMAT=<ID=CN,Number=1,Type=Integer,Description=\"Estimated copy number\">"):
                outfile.write(line)
                outfile.write("##FORMAT=<ID=ECN,Number=1,Type=Integer,Description=\"Expected copy number\">\n")
                continue
            elif not line.startswith("#"):
                line = re.sub(r";END", ";ALGORITHMS=depth;END", line)
                line = re.sub(r":PE", ":PE:ECN", line)
                line = line.strip() + ":2\n"
            outfile.write(line)

    # Extract DUP and DEL variants
    extract_variants(mod_vcf, dup_vcf, "DUP")
    extract_variants(mod_vcf, del_vcf, "DEL")

    # Create BED files
    create_bed_file(del_vcf, sample_id, "DEL")
    create_bed_file(dup_vcf, sample_id, "DUP")

def extract_variants(input_vcf, output_vcf, variant_type):
    """
    Extracts variants of a specific type (DUP or DEL) from the modified VCF file.

    Args:
        input_vcf (str): The input modified VCF file.
        output_vcf (str): The output VCF file containing specific variant types.
        variant_type (str): The type of variant to extract (DUP or DEL).
    """
    with open(input_vcf, 'r') as infile, open(output_vcf, 'w') as outfile:
        for line in infile:
            if re.search(r"<{}>|^#".format(variant_type), line):
                outfile.write(line)

def create_bed_file(vcf_file, sample_id, variant_type):
    """
    Creates a BED file for a specific variant type from a VCF file.

    Args:
        vcf_file (str): The input VCF file.
        sample_id (str): The sample ID.
        variant_type (str): The type of variant (DUP or DEL).
    """
    bed_file = f"{sample_id}.cnv.mod.{variant_type}.bed"
    with open(vcf_file, 'r') as infile, open(bed_file, 'w') as outfile:
        for line in infile:
            if not line.startswith("#"):
                cols = line.strip().split("\t")
                chrom = cols[0]
                start = cols[1]
                end_match = re.search(r"END=(\d+);", line)
                if end_match:
                    end = end_match.group(1)
                    outfile.write("{}\t{}\t{}\t{}\t{}\n".format(chrom, start, end, variant_type, sample_id))

def print_version():
    """Prints the version of the script."""
    print(f"sample_preprocessing.py version {VERSION}")

def print_help():
    """Prints the help message."""
    print("Usage: sample_preprocessing.py --sample_id <sample_ids> --path <vcf_paths>")
    print("Options:")
    print("  -v, --version    Show version information and exit.")
    print("  -h, --help       Show this help message and exit.")
    print("Arguments:")
    print("  --sample_id      List of sample IDs (e.g., 24709 24713).")
    print("  --path           List of VCF file paths corresponding to the sample IDs (e.g., /path/to/24709.cnv.vcf.gz /path/to/24713.cnv.vcf.gz).")
    print("\nExample:")
    print("  ./sample_preprocessing.py --sample_id 24709 24713 --path /path/to/24709.cnv.vcf.gz /path/to/24713.cnv.vcf.gz")

def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--sample_id", nargs="+", help="List of sample IDs")
    parser.add_argument("--path", nargs="+", help="List of VCF file paths")
    parser.add_argument("-v", "--version", action="store_true", help="Show version information and exit")
    parser.add_argument("-h", "--help", action="store_true", help="Show help message and exit")
    args = parser.parse_args()

    # Display version or help if requested
    if args.version:
        print_version()
        return
    if args.help:
        print_help()
        return

    # Ensure sample_id and path have the same number of elements
    if len(args.sample_id) != len(args.path):
        print("Error: The number of sample IDs and VCF paths must be the same.")
        print_help()
        return

    # Process the samples
    samples = list(zip(args.sample_id, args.path))
    create_ploidy_table(samples)
    for sample_id, vcf_path in samples:
        process_vcf(sample_id, vcf_path)

if __name__ == "__main__":
    main()
