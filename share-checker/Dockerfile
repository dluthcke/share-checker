FROM alpine:3.18

# Install tools for NFS and health check
RUN apk add --no-cache bash netcat-openbsd nfs-utils

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["sleep", "infinity"]
