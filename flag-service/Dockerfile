# Etapa 1: instala as bibliotecas Python num ambiente isolado (venv)
FROM python:3.11-slim AS builder
WORKDIR /app
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Etapa 2: imagem final, so com as bibliotecas prontas e o codigo
FROM python:3.11-slim
WORKDIR /app
RUN useradd -m appuser
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY --chown=appuser:appuser . .
USER appuser
EXPOSE 8002
CMD ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
