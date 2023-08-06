#!/bin/bash 
echo "Starting Up" 
# Your comma-separated string list
 

# Set the Internal Field Separator to comma (,)
IFS=','

# Iterate over the elements in the list using a for loop
for name in $CLOUDFLARE_ANAMES; do 
    echo "Processing cname: $name"
    /usr/local/bin/cloudflare.sh $name 
done

# Reset the Internal Field Separator to its default value (space, tab, and newline)
unset IFS
 
 
