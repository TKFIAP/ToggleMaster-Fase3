FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
RUN useradd -m appuser
RUN chown -R appuser:appuser /app
USER appuser
EXPOSE 8003
CMD ["gunicorn", "--bind", "0.0.0.0:8003", "app:app"]



