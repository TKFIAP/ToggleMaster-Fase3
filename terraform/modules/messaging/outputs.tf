output "queue_url" {
  description = "Endereco da fila SQS"
  value       = aws_sqs_queue.events.url
}