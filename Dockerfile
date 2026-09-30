FROM golang:1.25-alpine AS builder
WORKDIR /app

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o millionws . \
	&& CGO_ENABLED=0 GOOS=linux go build -o loadgen ./cmd/loadgen

# Load generator: docker build --target loadgen .
FROM gcr.io/distroless/static-debian12 AS loadgen
COPY --from=builder /app/loadgen /loadgen
USER nonroot:nonroot
ENTRYPOINT ["/loadgen"]

# Server, the default target.
FROM gcr.io/distroless/base-debian12 AS server
WORKDIR /app
COPY --from=builder /app/millionws /app/millionws

EXPOSE 8080
USER nonroot:nonroot

ENTRYPOINT ["/app/millionws"]
CMD ["-port=8080"]
