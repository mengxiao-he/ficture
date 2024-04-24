#!/usr/bin/bash

# Initialize variables
brc_parq=
mtx_path=
opath=

# Process options
while (( "$#" )); do
  case "$1" in
    -h|--help)
      echo "Usage: $0 -p|--position [brc_parq] -m|--matrix [mtx_path] -o|--output [opath]"
      echo "  -p|--position: path to the tissue_positions.parquet file"
      echo "  -m|--matrix: path to the filtered_feature_bc_matrix folder"
      echo "  -o|--output: output path"
      exit 0
      ;;
    -p|--position)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        brc_parq=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -m|--matrix)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        mtx_path=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    -o|--output)
      if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
        opath=$2
        shift 2
      else
        echo "Error: Argument for $1 is missing" >&2
        exit 1
      fi
      ;;
    *)
      echo "Error: Unsupported flag $1" >&2
      exit 1
      ;;
  esac
done

# Check if variables are set
if [ -z "$brc_parq" ] || [ -z "$mtx_path" ] || [ -z "$opath" ]; then
  echo "Error: One or more flags are missing or not set correctly" >&2
  exit 1
fi

# Define input and output files
bfile="${mtx_path}/barcodes.tsv.gz"
mfile="${mtx_path}/matrix.mtx.gz"
ffile="${mtx_path}/features.tsv.gz"

# Activate environment
source /home/mengxiao.he/bin/miniconda3/etc/profile.d/conda.sh
conda activate ficture

# Path to your R script
R_SCRIPT_PATH="/home/mengxiao.he/Visium_HD/ficture/ficture_preproc.R"

# Call Rscript with your script and arguments
echo "Running R script..."
Rscript $R_SCRIPT_PATH $bfile $mfile $ffile $brc_parq $opath
echo "Finished running R script."

# Deactivate environment
conda deactivate

# Done