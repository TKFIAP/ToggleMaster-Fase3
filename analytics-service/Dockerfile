FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
RUN useradd -m appuser
RUN chown -R appuser:appuser /app
USER appuser
EXPOSE 8005
CMD ["gunicorn", "--bind", "0.0.0.0:8005", "app:app"]






