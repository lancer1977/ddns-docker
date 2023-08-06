#!/bin/bash

validate_ip() {
    local ip=$1
    local ip_pattern="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
    local octet_pattern="([0-9]{1,3})"
    
    if [[ ! $ip =~ $ip_pattern ]]; then
        echo "Invalid IP address format: $ip"
        return 1
    fi

    # Check if each octet is within the range of 0 to 255
    for octet in $(echo "$ip" | grep -oE "$octet_pattern"); do
        if ((octet > 255)); then
            echo "Invalid IP address: $ip (Octet value out of range)"
            return 1
        fi
    done

    echo "Valid IP address: $ip"
    return 0
}

RECORD_NAME=$2
TARGET_IP=$(curl -s https://ipinfo.io/ip)
if (validate_ip $TARGET_IP); then
	exit 1
fi

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
