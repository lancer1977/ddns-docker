FROM alpine:latest
env EMAIL "YOUR_EMAIL"
env API_KEY "YOUR_CLOUDFLARE_API_KEY"
env ZONE_ID "YOUR_CLOUDFLARE_ZONE_ID"
env API_TOKEN "YOUR_CLOUDFLARE_API_TOKEN"
ENV DOMAIN "polyhydragames.com"
ENV CLOUDFLARE_ANAMES "dashy,api,identity"
ENV CRON_VALUE "0 * * * *"
# Replace with your desired CNAME record name


# Use a base image with a Linux distribution of your choice
#FROM ubuntu:latest

# Install necessary packages (curl in this case) if required
RUN apk --no-cache add curl
#RUN apt-get update && apt-get install -y curl wget UBUNTU

# Copy the Linux script into the container
COPY loop.sh /loop.sh
COPY cloudflare.sh /cloudflare.sh

# Set execute permissions for the script
RUN chmod +x /*.sh

RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
RUN chmod +x yq
RUN mv yq /usr/local/bin/

#RUN echo "${CRON_VALUE} /bin/bash /usr/local/bin/loop.sh" > /etc/cron.d/script-cron
RUN echo "$CRON_VALUE /bin/bash /loop.sh" > /var/spool/cron/crontabs/root



# Start the cron service
#CMD cron && tail -f /dev/null

#FOR TESTING
#CMD ["/usr/local/bin/loop.sh"]

ENTRYPOINT ["/loop.sh"]

# Start the cron service in the foreground
CMD ["crond", "-f"]
