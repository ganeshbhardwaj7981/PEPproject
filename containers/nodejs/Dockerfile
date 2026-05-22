FROM node:20-alpine

# Create non-root user for security
RUN addgroup -S runner && adduser -S runner -G runner

WORKDIR /sandbox

# Switch to non-root user
USER runner

# Default entrypoint: run whatever code.js is mounted
CMD ["node", "/sandbox/code.js"]
