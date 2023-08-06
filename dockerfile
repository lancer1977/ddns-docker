FROM alpine:latest
env EMAIL "YOUR_EMAIL"
env API_KEY "YOUR_CLOUDFLARE_API_KEY"
env ZONE_ID "YOUR_CLOUDFLARE_ZONE_ID"
env API_TOKEN "YOUR_CLOUDFLARE_API_TOKEN"
ENV DOMAIN "polyhydragames.com"
ENV CLOUDFLARE_ANAMES "dashy,api,identity"
ENV CRON_VALUE "1 * * * *"

# Install necessary packages (curl in this case) if required
RUN apk update && apk add --no-cache bash dcron curl
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O yq
RUN chmod +x yq
RUN mv yq /usr/local/bin/
RUN mkdir /logs
RUN echo -e "#!/bin/sh\n\
echo \"\$CRON_VALUE /scripts/loop.sh\" > /var/spool/cron/crontabs/root\n\
crond -f" > /entrypoint.sh

RUN chmod +x /entrypoint.sh

# Copy the Linux script into the container
COPY loop.sh /scripts/loop.sh
COPY cloudflare.sh /scripts/cloudflare.sh

# Set execute permissions for the script
RUN chmod +x /scripts/*.sh

# Set the entrypoint script as the entry point for the container
ENTRYPOINT ["/entrypoint.sh"]