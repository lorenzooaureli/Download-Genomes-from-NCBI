#!/bin/bash

# =============================================================================
# NCBI Genome Downloader
# =============================================================================
#
# This script downloads genome sequences from NCBI based on accession numbers.
#
# Usage:
#   1. Download genomes from a file containing accession numbers:
#      ./script.sh [--compress] [--h_version] accessions.txt output_dir [num_parallel]
#
#   2. Download genomes by specifying accessions directly:
#      ./script.sh [--compress] [--h_version] --accession GCA_000001405.29 GCA_000002035.4 output_dir [num_parallel]
#
# Parameters:
#   --compress       Optional: Keep files compressed and create a tar.gz archive
#   --h_version      Optional: Search for the highest version of each accession
#   --accession      Optional: Specify accessions directly on command line
#   accessions.txt   File with one accession number per line (if not using --accession)
#   output_dir       Directory where genomes will be saved
#   num_parallel     Optional: Number of parallel downloads (default: 4)
#
# Examples:
#   ./script.sh genomes.txt ./downloaded_genomes 8
#   ./script.sh --compress genomes.txt ./downloaded_genomes
#   ./script.sh --h_version --accession GCA_000013925.1 ./my_genomes 6
#   ./script.sh --compress --h_version --accession GCA_000001405.29 GCA_000002035.4 ./my_genomes
#
# =============================================================================

# Parse command line arguments
COMPRESS=false
HIGHEST_VERSION=false
ACCESSIONS=()
POSITIONAL_ARGS=()
PARSING_ACCESSIONS=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --compress)
      COMPRESS=true
      shift
      ;;
    --h_version)
      HIGHEST_VERSION=true
      shift
      ;;
    --accession)
      PARSING_ACCESSIONS=true
      shift
      while [[ $# -gt 0 && ! "$1" == --* && ! "$1" == -* ]]; do
        if [[ "$1" =~ ^GC[AF]_[0-9]+(\.[0-9]+)?$ ]]; then
          ACCESSIONS+=("$1")
          shift
        else
          break
        fi
      done
      PARSING_ACCESSIONS=false
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

# Reset positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Check usage based on input method
if [ ${#ACCESSIONS[@]} -eq 0 ] && [ $# -lt 2 ]; then
  echo "Usage: $0 [--compress] [--accession GCA_XXXXXX GCA_YYYYYY ...] <output_directory> [num_parallel]"
  echo "   OR: $0 [--compress] <accession_file> <output_directory> [num_parallel]"
  exit 1
fi

# Determine input method and set variables
if [ ${#ACCESSIONS[@]} -gt 0 ]; then
  # Direct accessions provided via command line
  OUTPUT_DIR="$1"
  NUM_PARALLEL="${2:-4}"
  TEMP_FILE=$(mktemp)
  printf "%s\n" "${ACCESSIONS[@]}" > "$TEMP_FILE"
  ACCESSION_FILE="$TEMP_FILE"
  USING_TEMP=true

  echo "Using accessions: ${ACCESSIONS[*]}"
  echo "Output directory: $OUTPUT_DIR"
  echo "Parallel downloads: $NUM_PARALLEL"
else
  # Accession file provided
  ACCESSION_FILE="$1"
  OUTPUT_DIR="$2"
  NUM_PARALLEL="${3:-4}"
  USING_TEMP=false

  # Check if the accession file exists
  if [ ! -f "$ACCESSION_FILE" ]; then
    echo "Error: Accession file '$ACCESSION_FILE' does not exist."
    exit 1
  fi

  echo "Using accession file: $ACCESSION_FILE"
  echo "Output directory: $OUTPUT_DIR"
  echo "Parallel downloads: $NUM_PARALLEL"
fi

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to find the highest version of an accession
find_highest_version() {
  base_accession="$1"

  # Extract the base part without version
  if [[ "$base_accession" =~ ^(GC[AF]_[0-9]+)(\.[0-9]+)?$ ]]; then
    accession_base="${BASH_REMATCH[1]}"
  else
    echo "Invalid accession format: $base_accession" >&2
    echo "$base_accession"  # Return the original accession
    return
  fi

  # Convert accession number to FTP path format
  base="${accession_base:0:3}"
  section1="${accession_base:4:3}"
  section2="${accession_base:7:3}"
  section3="${accession_base:10:3}"

  # Construct the base FTP URL
  base_url="ftp://ftp.ncbi.nlm.nih.gov/genomes/all/$base/$section1/$section2/$section3"

  echo "Searching for highest version of $accession_base..." >&2

  # Get all versions of this accession
  versions=$(curl -s "$base_url/" | grep -i "${accession_base}\." | awk '{print $9}' | sort -V)

  if [ -z "$versions" ]; then
    echo "No versions found for $accession_base" >&2
    echo "$base_accession"  # Return the original accession
    return
  fi

  # Get the highest version
  highest_version=$(echo "$versions" | grep -o "${accession_base}\.[0-9]\+" | sort -V | tail -n 1)

  if [ -z "$highest_version" ]; then
    echo "Could not determine highest version for $accession_base" >&2
    echo "$base_accession"  # Return the original accession
    return
  fi

  echo "Found highest version: $highest_version (original: $base_accession)" >&2
  echo "$highest_version"
}

# Function to construct FTP URL and download
download_genome_ftp() {
  accession="$1"
  output_dir="$2"
  compress="$3"
  highest_version="$4"

  # Skip empty lines or invalid accessions
  if [[ -z "$accession" || "$accession" != GCA_* && "$accession" != GCF_* ]]; then
    echo "Skipping invalid accession: $accession"
    return
  fi

  # If highest_version flag is set, find the highest version
  if [ "$highest_version" = "true" ]; then
    accession=$(find_highest_version "$accession")
  fi

  # Convert accession number to FTP path format
  base="${accession:0:3}"
  section1="${accession:4:3}"
  section2="${accession:7:3}"
  section3="${accession:10:3}"
  section4="${accession:13}"

  # Construct the base FTP URL
  base_url="ftp://ftp.ncbi.nlm.nih.gov/genomes/all/$base/$section1/$section2/$section3"

  # First, we need to find the actual directory name which includes the assembly suffix
  echo "Looking for assembly directory for $accession..."
  assembly_dir=$(curl -s "$base_url/" | grep -i "$accession" | awk '{print $9}')

  if [ -z "$assembly_dir" ]; then
    echo "Could not find assembly directory for $accession"
    return
  fi

  echo "Found assembly directory: $assembly_dir"

  # Construct the full FTP URL with the assembly directory
  ftp_url="$base_url/$assembly_dir"

  echo "Attempting to download $accession from $ftp_url..."

  # Try downloading the .fna file
  wget -q --show-progress -P "$output_dir" "$ftp_url/${assembly_dir}_genomic.fna.gz" \
    || echo "Failed to download $accession"

  # Process based on compression flag
  if [ -f "$output_dir/${assembly_dir}_genomic.fna.gz" ]; then
    # Rename the file to use the accession number for consistency
    mv "$output_dir/${assembly_dir}_genomic.fna.gz" "$output_dir/${accession}_genomic.fna.gz"

    if [ "$compress" = "false" ]; then
      gunzip -f "$output_dir/${accession}_genomic.fna.gz"
      echo "Downloaded and extracted: $accession"
    else
      echo "Downloaded (kept compressed): $accession"
    fi
  else
    echo "Download failed: $accession"
  fi
}

export -f download_genome_ftp find_highest_version  # Export functions for parallel

# Use GNU parallel to download in parallel
if [ "$HIGHEST_VERSION" = "true" ]; then
  echo "Using highest version mode - will search for the latest version of each accession"
  cat "$ACCESSION_FILE" | grep -E '^GC[AF]_[0-9]+(\.[0-9]+)?$' | parallel -j "$NUM_PARALLEL" download_genome_ftp {} "$OUTPUT_DIR" "$COMPRESS" "$HIGHEST_VERSION"
else
  cat "$ACCESSION_FILE" | grep -E '^GC[AF]_[0-9]+(\.[0-9]+)?$' | parallel -j "$NUM_PARALLEL" download_genome_ftp {} "$OUTPUT_DIR" "$COMPRESS" "$HIGHEST_VERSION"
fi

# Create tar.gz archive if compress flag is set
if [ "$COMPRESS" = "true" ]; then
  ARCHIVE_NAME="genomes_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo "Creating compressed archive $ARCHIVE_NAME..."
  tar -czf "$ARCHIVE_NAME" -C "$OUTPUT_DIR" .
  echo "Archive created successfully."
fi

# Clean up temp file if used
if [ "$USING_TEMP" = "true" ]; then
  rm -f "$TEMP_FILE"
fi

echo "All downloads completed in '$OUTPUT_DIR' directory."
