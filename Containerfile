# podman build -t devfile-index -f Containerfile .
# podman tag devfile-index disconn-harbor.d70.kemo.labs/library/devfile-index:latest
# podman push disconn-harbor.d70.kemo.labs/library/devfile-index:latest
###################################################
# Build
FROM registry-access-redhat-ptc.jfrog.lab.kemo.network/ubi8/go-toolset:1.21 AS builder
# Run tasks as root
USER 0
# Install yq
RUN curl -sL -O https://github.com/mikefarah/yq/releases/download/v4.9.5/yq_linux_amd64 -o /usr/local/bin/yq && mv ./yq_linux_amd64 /usr/local/bin/yq && chmod +x /usr/local/bin/yq
# Download the registry build tools
RUN git clone --depth=1 https://github.com/devfile/registry-support.git /registry-support
# Copy registry contents
COPY . /registry
# Run the registry build tools
RUN echo '{}' > /registry/last_modified.json \
 && /registry-support/build-tools/build.sh /registry /build
# Reset user as non-root
USER 1001

###################################################
# Packaging
FROM quay-ptc.jfrog.lab.kemo.network/devfile/devfile-index-base:next
COPY --from=builder /build/index.json /index.json
COPY --from=builder /build/stacks /registry/stacks
