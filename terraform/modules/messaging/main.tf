# A fila de mensagens entre o evaluation-service e o analytics-service
resource "aws_sqs_queue" "events" {
  name = "${var.project_name}-events"

  tags = {
    Name = "${var.project_name}-events"
  }
}