# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Copy source code
COPY *.go ./
COPY statics ./statics/

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o invoicer .

# Final stage
FROM alpine:latest

# Add security updates and ca-certificates
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -g 10001 -S app && \
    adduser -u 10001 -S app -G app

WORKDIR /app

# Copy binary and static files from builder
COPY --from=builder /build/invoicer /app/invoicer
COPY --from=builder /build/statics /app/statics/

# Use non-root user
USER app

EXPOSE 8080

ENTRYPOINT ["/app/invoicer"]
