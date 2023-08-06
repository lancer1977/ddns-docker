#!/bin/bash

 
RECORD_NAME=$1
TARGET_IP=$(curl -s https://ipinfo.io/ip)
 

ADDRESS=${RECORD_NAME}.${DOMAIN}

# Print the external IP address
echo "My external IP address is: $TARGET_IP"
echo "Attempting ot update  address for $ADDRESS"
# Call the Cloudflare API to update the CNAME record

RECORD_JSON=$(curl -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${ADDRESS}" -H "X-Auth-Email: ${EMAIL}"  -H "X-Auth-Key: ${API_KEY}") 
echo $RECORD_JSON > $HOME/temp.txt

RECORD_ID=$(echo "$RECORD_JSON" | yq '.result[0].id' $HOME/temp.txt)
echo $RECORD_ID

curl -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
	-H "Authorization: Bearer ${API_TOKEN}" \
	-H "X-Auth-Email: ${EMAIL}" \
	-H "X-Auth-Key: ${API_KEY}" \
	-H "Content-Type: application/json" \
	--data '{"type": "A", "name": "'$ADDRESS'", "content": "'${TARGET_IP}'", "ttl": 1, "proxied": false}'
