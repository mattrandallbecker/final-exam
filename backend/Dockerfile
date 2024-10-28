# https://hub.docker.com/_/golang
FROM golang:1.23 AS builder
# Create and change to the app directory.
WORKDIR /app
# Retrieve application dependencies using go modules.
COPY go.* ./
RUN go mod download
# Copy local code to the container image.
COPY . ./
# -mod=readonly ensures immutable go.mod and go.sum in container builds.
RUN CGO_ENABLED=0 GOOS=linux go build -mod=readonly -v -o main

# Build the runtime container image from scratch, copying what is needed from the previous stage.  
FROM scratch
# Copy the binary to the production image from the builder stage.
COPY --from=builder /app/main /main
# Expose port
EXPOSE 8080
# Run the web service on container startup.
ENTRYPOINT ["/main"]
