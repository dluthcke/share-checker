# Share Docker CI

A Docker Compose setup with `share-checker` to verify network shares and an `app` running `hello-world`.
Current functionality is limited to NFS shares, SMB shares are expected to be added in a future release.
To request different share types, please open an issue.

## Structure

- `share-checker/Dockerfile`: Builds `share-checker`.
- `share-checker/entrypoint.sh`: Verifies shares.
- `docker-compose.yml`: Defines services.
- `.github/workflows/ci.yml`: CI pipeline.
- `README.md`: This file.

## Environment Variables

- `DEBUG`: Enable debugging for the container with "true"
- `TIMEOUT`: Set the timeout to keep looking for shares. Default is 60 seconds
- `INTERVAL`: Set the interval to retry share lookup after a failure. Default is 5 Seconds
- `NFS[0-9]`: Add NFS shares to lookup in `server:/path/to/share` format. Each share should have a different number

## Local Setup

1. **Build**:
   ```bash
   cd share-checker
   docker build -t share-checker:latest .
   cd ..
   ```

2. **Deploy**
  ```bash
  # Via Docker run
  docker run --name share-checker \
  -e NFS1=server1:/mnt/storage/share1 \
  -e NFS2=server2:/mnt/storage/share2 \
  -e TIMEOUT=60 \
  --health-cmd="test -f /tmp/shares-ready" \
  --health-interval=10s  \
  --health-timeout=5s  \
  --health-retries=3  \
  --health-start-period=10s \
  sharecheckertest:latest

  # Via Docker Compose
  docker compose up -d
  ```
