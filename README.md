# Download Genomes from NCBI

A collection of bash scripts to download genome sequences from NCBI's FTP server using genome accession numbers.

## Features

- Download genomes from NCBI using GCA or GCF accession numbers
- Support for both parallel and sequential downloads
- Automatic highest version detection for accession numbers
- Optional compression and archiving
- Flexible input methods (file or command-line arguments)
- Progress tracking during downloads

## Prerequisites

- `bash` (version 4.0 or higher)
- `wget` - for downloading files
- `curl` - for querying NCBI FTP directories
- `GNU parallel` - required for parallel downloads (download_genomes_gnu.sh only)

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install wget curl parallel
```

**macOS:**
```bash
brew install wget curl parallel
```

**CentOS/RHEL:**
```bash
sudo yum install wget curl parallel
```

## Scripts

### 1. download_genomes_gnu.sh
Downloads genomes in parallel using GNU parallel for faster processing.

**Usage:**
```bash
./download_genomes_gnu.sh [OPTIONS] <accession_file> <output_dir> [num_parallel]
./download_genomes_gnu.sh [OPTIONS] --accession <ACC1> <ACC2> ... <output_dir> [num_parallel]
```

**Parameters:**
- `num_parallel` - Number of parallel downloads (default: 4)

### 2. download_genomes_sequential.sh
Downloads genomes sequentially, one at a time. Useful when parallel downloads are not desired or when GNU parallel is not available.

**Usage:**
```bash
./download_genomes_sequential.sh [OPTIONS] <accession_file> <output_dir>
./download_genomes_sequential.sh [OPTIONS] --accession <ACC1> <ACC2> ... <output_dir>
```

## Options

Both scripts support the following options:

- `--compress` - Keep files compressed (.gz) and create a tar.gz archive of all downloads
- `--h_version` - Automatically search for and download the highest version of each accession
- `--accession` - Specify accession numbers directly on the command line instead of using a file

## Accession File Format

Create a text file with one accession number per line. Empty lines are ignored.

**Example (genome_list.txt):**
```
GCF_000005845.1
GCA_012931705.2
GCA_034298135.1
```

## Examples

### Basic Usage

Download genomes from a file (parallel):
```bash
./download_genomes_gnu.sh genome_list.txt ./downloaded_genomes
```

Download genomes from a file (sequential):
```bash
./download_genomes_sequential.sh genome_list.txt ./downloaded_genomes
```

### Using Command-Line Accessions

Download specific genomes without creating a file:
```bash
./download_genomes_gnu.sh --accession GCF_000005845.1 GCA_012931705.2 ./my_genomes
```

### Parallel Downloads

Download with 8 parallel connections:
```bash
./download_genomes_gnu.sh genome_list.txt ./downloaded_genomes 8
```

### Compressed Output

Keep files compressed and create a tar.gz archive:
```bash
./download_genomes_gnu.sh --compress genome_list.txt ./downloaded_genomes
```

This will:
1. Download all genomes
2. Keep them in .gz format
3. Create a timestamped archive: `genomes_YYYYMMDD_HHMMSS.tar.gz`

### Highest Version Mode

Automatically download the latest version of each accession:
```bash
./download_genomes_gnu.sh --h_version genome_list.txt ./downloaded_genomes
```

If you specify `GCA_000013925.1`, the script will search for and download the highest available version (e.g., `GCA_000013925.3` if available).

### Combined Options

Combine multiple options:
```bash
./download_genomes_gnu.sh --compress --h_version --accession GCA_000001405.29 GCA_000002035.4 ./my_genomes 6
```

## Output

Downloaded genome files are named using the accession number:
```
GCF_000005845.1_genomic.fna       # Uncompressed
GCF_000005845.1_genomic.fna.gz    # Compressed (with --compress flag)
```

## Accession Format

Both scripts accept NCBI genome accession numbers in the format:
- `GCA_XXXXXXXXX.Y` (GenBank assemblies)
- `GCF_XXXXXXXXX.Y` (RefSeq assemblies)

Where:
- `XXXXXXXXX` is a 9-digit number
- `.Y` is the version number (optional when using `--h_version`)

## Error Handling

- Invalid accessions are automatically skipped
- Failed downloads are reported but don't stop the process
- Empty lines in accession files are ignored

## Notes

- Downloads are retrieved from NCBI's FTP server: `ftp://ftp.ncbi.nlm.nih.gov/genomes/all/`
- The parallel version (download_genomes_gnu.sh) is significantly faster for multiple genomes
- The sequential version is more suitable for limited bandwidth or resource-constrained environments
- Progress is displayed during downloads

## Troubleshooting

**GNU parallel not found:**
- Install GNU parallel or use the sequential version instead

**Connection errors:**
- Check your internet connection
- NCBI FTP server might be temporarily unavailable
- Some institutional firewalls may block FTP access

**Accession not found:**
- Verify the accession number is correct
- Try using `--h_version` to search for available versions
- Check if the genome is available on NCBI's website first

## License

This project is open source and available for use in academic and research settings.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
