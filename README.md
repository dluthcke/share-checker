# Share Docker CI

A Docker Compose setup with `share-checker` to verify network shares and an `app` running `hello-world`.

## Structure

- `share-checker/Dockerfile`: Builds `share-checker`.
- `share-checker/entrypoint.sh`: Verifies shares.
- `docker-compose.yml`: Defines services.
- `.github/workflows/ci.yml`: CI pipeline.
- `README.md`: This file.

## Local Setup

1. **Build**:
   ```bash
   cd share-checker
   docker build -t share-checker:latest .
   cd ..
