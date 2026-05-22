FROM python:3.12-alpine

# Create non-root user for security
RUN addgroup -S runner && adduser -S runner -G runner

WORKDIR /sandbox

# Install only essential packages
RUN pip install --no-cache-dir --upgrade pip

# Switch to non-root user
USER runner

# Default entrypoint: run whatever code.py is mounted
CMD ["python", "/sandbox/code.py"]
