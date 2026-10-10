# Etapa 1: compila o codigo Go e gera um executavel unico
FROM golang:1.26 AS builder
WORKDIR /app
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o main .

# Etapa 2: imagem final enxuta, so com o executavel (sem o Go instalado)
FROM alpine:3.20
WORKDIR /app
RUN adduser -D appuser
COPY --from=builder --chown=appuser:appuser /app/main .
USER appuser
EXPOSE 8001
CMD ["./main"]
