#!/usr/bin/bash

# Initialize variables
path=
opath=

# Process options
while (("$#")); do
    case "$1" in
    -h | --help)
        echo "Usage: $0 -p|--path [path] -o|--output [output]"
        echo "  -p|--path: path to base directory with input files"
        echo "  -o|--output: path to output directory"
        echo "Required files transcripts.tsv.gz, feature.clean.tsv.gz, coordinate_minmax.tsv and scalefactors_json.json"
        exit 0
        ;;
    -p | --path)
        if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
            path=$2
            shift 2
        else
            echo "Error: Argument for $1 is missing" >&2
            exit 1
        fi
        ;;
    -o | --output)
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
if [ -z "$path" ] || [ -z "$opath" ]; then
    echo "Error: One or more path is missing" >&2
    exit 1
fi

# Activate environment
source /home/mengxiao.he/bin/miniconda3/etc/profile.d/conda.sh
conda activate ficture

# Set initial parameters
scalefactors=${path}/scalefactors_json.json
scale=$(jq ".microns_per_pixel" ${scalefactors})
mu_scale=$(echo "scale=20; 1/${scale}" | bc)
key=Count
MJ=X # If your data is sorted by the X-axis
gitpath=/home/mengxiao.he/repositories/ficture # path to where you have installed ficture

# Create pixel minibatches
input=${path}/transcripts.tsv.gz
output=${opath}/batched.matrix.tsv.gz
/home/mengxiao.he/repositories/ficture/examples/script/generic_I.sh input=${input} output=${output} MJ=${MJ} gitpath=${gitpath} &
jobid1=$!
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Creating pixel minibatches" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt

# Parameters for initializing the model
nFactor=12 # Number of factors
sliding_step=2
train_nEpoch=3
train_width=18 # \sqrt{3} x the side length of the hexagon (um)
model_id=nF${nFactor}.d_${train_width} # An identifier kept in output file names
min_ct_per_feature=20 # Ignore genes with total count \< 20
R=10 # We use R random initializations and pick one to fit the full model
thread=4 # Number of threads to use
feature=${path}/feature.clean.tsv.gz

# Parameters for pixel level decoding
fit_width=18 # Often equal or smaller than train_width (um)
anchor_res=4 # Distance between adjacent anchor points (um)
radius=$(($anchor_res+1))
anchor_info=prj_${fit_width}.r_${anchor_res} # An identifier
coor=${path}/coordinate_minmax.tsv

# Model fitting

# Prepare training minibatches, only need to run once if you plan to fit multiple models (say with different number of factors)
input=${path}/transcripts.tsv.gz
hexagon=${opath}/hexagon.d_${train_width}.tsv.gz
/home/mengxiao.he/repositories/ficture/examples/script/generic_II.sh gitpath=${gitpath} key=${key} mu_scale=${mu_scale} major_axis=${MJ} path=${path} input=${input} output=${hexagon} width=${train_width} sliding_step=${sliding_step} &
jobid2=$!
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Preparing training minibatches" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt

# Model training
wait $jobid2
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Finished preparing training minibatches" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt
/home/mengxiao.he/repositories/ficture/examples/script/generic_III.sh gitpath=${gitpath} key=${key} mu_scale=${mu_scale} major_axis=${MJ} path=${opath} pixel=${input} hexagon=${hexagon} feature=${feature} model_id=${model_id} train_width=${train_width} nFactor=${nFactor} R=${R} train_nEpoch=${train_nEpoch} fit_width=${fit_width} anchor_res=${anchor_res} min_ct_per_feature=${min_ct_per_feature} thread=${thread} &
jobid3=$!
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Model training" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt

# Pixel level decoding & visualization
wait $jobid3 $jobid1
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Finished creating minibatches and model training" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt
/home/mengxiao.he/repositories/ficture/examples/script/generic_V.sh gitpath=${gitpath} key=${key} mu_scale=${mu_scale} path=${opath} model_id=${model_id} anchor_info=${anchor_info} radius=${radius} coor=${coor} thread=${thread} &
jobid4=$!
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Pixel level decoding & visualization" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt

# Wait for the process to finish and then print a message
wait ${jobid4}
echo "==============================================" | tee -a ${opath}/time_log.txt
echo "Finished pixel level decoding & visualization" | tee -a ${opath}/time_log.txt
echo "$(date)" | tee -a ${opath}/time_log.txt
echo "==============================================" | tee -a ${opath}/time_log.txt