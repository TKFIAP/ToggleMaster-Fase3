FROM golang:1.26 AS builder
WORKDIR /app
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o main .

FROM golang:1.26-alpine
WORKDIR /app
RUN adduser -D appuser
COPY --from=builder --chown=appuser:appuser /app/main .
USER appuser
EXPOSE 8004
CMD ["./main"]
