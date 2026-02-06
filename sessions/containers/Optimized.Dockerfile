##############################
# Optimized Multi-Stage Dockerfile (Go)
##############################

# --- Builder stage: compile statically on a pinned Go base
FROM golang:1.24-alpine AS builder

# Avoid installing extra tools/packages unless needed
WORKDIR /src

# Cache-friendly: download modules before copying the full source
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Deterministic, smaller static binary
ARG TARGETOS=linux
ARG TARGETARCH=amd64
ENV GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 GOFLAGS=-buildvcs=false
RUN go build -trimpath -ldflags "-s -w" -o /out/myapp .


# --- Final stage: minimal, non-root runtime with curl available
FROM alpine:3.20

# Install curl and create a non-root runtime user
RUN apk add --no-cache curl \
	&& adduser -D -u 10001 appuser

# Copy only the built artifact
COPY --from=builder /out/myapp /usr/local/bin/myapp

# Run as non-root for least privilege
USER appuser

# Document the listen port (Echo defaults to 8080 if PORT is unset)
EXPOSE 8080

# Healthcheck using curl to the app's health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
	CMD ["curl", "-fsS", "http://127.0.0.1:8080/healthz"]

# Use executable as entrypoint
ENTRYPOINT ["/usr/local/bin/myapp"]