FROM golang:1.24-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/pepinillo-api ./cmd/api

FROM alpine:3.20
RUN adduser -D -g '' appuser
WORKDIR /app
COPY --from=builder /bin/pepinillo-api /app/pepinillo-api
COPY --from=builder /src/migrations /app/migrations
USER appuser
EXPOSE 8080
CMD ["./pepinillo-api"]
