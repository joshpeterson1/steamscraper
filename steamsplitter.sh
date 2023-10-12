#!/bin/bash

# Check if the input file is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

# Extract the file extension and base name from the input filename
file_extension="${input_file##*.}"
base_name=$(basename "$input_file" ".$file_extension")

# Set the output extension based on the input file's extension
output_extension="$file_extension"
if [ "$file_extension" == "apng" ]; then
    output_extension="png"
fi

# Check if the file extension is gif or apng
if [[ "$file_extension" != "gif" && "$file_extension" != "apng" ]]; then
    echo "Unsupported file format. Please provide a GIF or APNG."
    exit 1
fi

# Step 1: Optimize
if [ "$file_extension" == "apng" ]; then
    # Disassemble the APNG
    apngdis "$input_file" "${base_name}_frame"

    # Optimize the PNG frames
    for frame in ${base_name}_frame*.png; do
        optipng "$frame"
    done

    # Reassemble the APNG into a new optimized file
    apngasm "${base_name}_optimized.apng" "${base_name}_frame*.png" 10 100
fi

# Use the optimized file for the split operation
if [ "$file_extension" == "apng" ]; then
    input_file="${base_name}_optimized.apng"
fi

# Step 2: Split

# Get the width of the file
dimensions=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$input_file")
width=$(echo $dimensions | cut -d'x' -f1)
# Calculate the width of each strip
strip_width=$((width / 5))

# Determine loop option based on file type
loop_option=""
if [ "$file_extension" == "gif" ]; then
    loop_option="-loop 0"
elif [ "$file_extension" == "apng" ]; then
    loop_option="-plays 0"
fi

# Split the file into 5 strips
for i in $(seq 0 4); do
    start_width=$((i * strip_width))
    ffmpeg -i "$input_file" -vf "crop=${strip_width}:in_h:${start_width}:0" -an -sn -frames:v 1 $loop_option "${base_name}-split$((i+1)).$output_extension"
done

# Step 3: Modify hex values for the split files
for i in $(seq 1 5); do
    perl -0777 -pi -e 's/\x00(?!.*\x00).*$/\x01\x49\x45\x4E\x44\x00\xD1\x1A\x4F\xE1/s' "${base_name}-split${i}.$output_extension"
done

echo "File split into 5 vertical strips: ${base_name}-split1.$output_extension, ${base_name}-split2.$output_extension, ..., ${base_name}-split5.$output_extension"
