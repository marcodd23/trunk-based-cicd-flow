# golang:1.21.2-alpine3.18 using digest
# Pull using digest to avoid image interception
FROM golang:1.23.2-alpine3.19 AS builder

#ARG APP_CMD_FOLDER
ARG REPO_NAME
ARG GIT_TOKEN
ARG VERSION
ARG REVISION

ARG VERSION_PATH=github.com/ingka-group-digital/${REPO_NAME}/pkg/version

ENV GOPRIVATE=github.com/ingka-group-digital/*

# Create and change to the app directory.
WORKDIR /app

# Configure git for private go modules
RUN apk update && apk add --no-cache git
RUN git config \
    --global \
    url."https://${GIT_TOKEN}@github.com/ingka-group-digital/".insteadOf "https://github.com/ingka-group-digital/"

# Retrieve application dependencies using go modules.
# Allows container builds to reuse downloaded dependencies.
COPY go.* ./
RUN go mod download

# Copy the source code to the container image.
COPY .. ./
RUN go mod tidy


# Build the binary.
# -mod=readonly ensures immutable go.mod and go.sum in container builds.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s -X '${VERSION_PATH}.Version=${VERSION}' -X '${VERSION_PATH}.Commit=${REVISION}'" -mod=readonly -v -o ./build/app ./cmd


############################
# Production STAGE: Build docker image
############################
# Use the official Alpine image for a lean production container.
# https://hub.docker.com/_/alpine
# https://docs.docker.com/develop/develop-images/multistage-build/#use-multi-stage-builds
FROM alpine:3

# Define arguments
ARG CREATED
ARG REVISION
ARG VERSION

# Add Maintainer Info
LABEL org.opencontainers.image.authors="ATP <atp-dev-group@ingka.ikea.com>"
LABEL org.opencontainers.image.created="${CREATED}"
LABEL org.opencontainers.image.revision="${REVISION}"
LABEL org.opencontainers.image.tag="${VERSION}"

RUN apk add --no-cache ca-certificates

# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/build/app /app/app
# COPY --from=builder /app/*.yaml ./
COPY --from=builder /app/deployment/config/property* /app/

# Ensure the binary has execute and read permissions
RUN chmod -R +rx /app

# Change to the app directory.
WORKDIR /app

# # Open port
EXPOSE 8080

# Will run as unprivileged user/group
#USER nobody:nobody

ENTRYPOINT ["./app"]
