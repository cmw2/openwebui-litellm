# This Dockerfile is not used for building - we use pre-built images from ghcr.io
# It exists only to satisfy azd's requirement for docker projects
# The actual images used are specified in azure.yaml and pulled from:
# - ghcr.io/berriai/litellm:main-latest
# - ghcr.io/open-webui/open-webui:main

FROM alpine:latest
RUN echo "This Dockerfile is a placeholder. Pre-built images are used from ghcr.io"
