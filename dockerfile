FROM ubuntu:latest
env EMAIL "YOUR_EMAIL"
env API_KEY "YOUR_CLOUDFLARE_API_KEY"
env ZONE_ID "YOUR_CLOUDFLARE_ZONE_ID"
env API_TOKEN "YOUR_CLOUDFLARE_API_TOKEN"
ENV DOMAIN "polyhydragames.com"   
ENV CRON_VALUE "0 0 * * *"
# Replace with your desired CNAME record name


# Use a base image with a Linux distribution of your choice
#FROM ubuntu:latest

# Install necessary packages (curl in this case) if required
RUN apt-get update && apt-get install -y curl wget
#MAKEDIR /config
# Copy the Linux script into the container
COPY *.sh /usr/local/bin/
COPY arecords.txt /config/arecords.txt
# Set execute permissions for the script
RUN chmod +x /usr/local/bin/*.sh

RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
RUN chmod +x yq
RUN mv yq /usr/local/bin/

RUN echo "${CRON_VALUE} /bin/bash /usr/local/bin/loop.sh" > /etc/cron.d/script-cron

# Start the cron service
#CMD cron && tail -f /dev/null

#FOR TESTING
CMD ["/usr/local/bin/loop.sh"]