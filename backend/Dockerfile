FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY go.mod .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /bin/pepinillo-api ./cmd/api

FROM alpine:3.20
RUN adduser -D -g '' appuser
USER appuser
WORKDIR /home/appuser
COPY --from=builder /bin/pepinillo-api ./pepinillo-api
EXPOSE 8080
CMD ["./pepinillo-api"]
