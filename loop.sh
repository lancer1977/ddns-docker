#!/bin/bash 
echo "Starting Up"
homedir=$HOME
input_file="/config/arecords.txt"

if [[ ! -f "$input_file" ]]; then
  echo "Error: Input file '$input_file' not found."
else
  # Read the words from the input file and iterate over them in a for loop
  while IFS= read -r word; do
    echo "Processing cname: $word"
    /usr/local/bin/cloudflare.sh $word
  done < "$input_file"
  echo "Successfully updated records."
fi
