# O cluster (o "cerebro" do Kubernetes, administrado pela AWS)
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids             = var.subnet_ids
    endpoint_public_access = true
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }
}

# Molde (Launch Template) das maquinas do cluster.
#
# Por que ele existe:
# Os servicos evaluation e analytics precisam acessar o SQS e o DynamoDB.
# Em vez de guardar chaves da AWS nos arquivos (inseguro), eles usam a
# permissao da propria maquina (a LabRole). Para isso, perguntam a um
# servico interno da maquina, o IMDS (Instance Metadata Service).
#
# O problema:
# Por padrao, o IMDS so responde a quem esta a 1 "salto" de rede (hop).
# Os pods rodam numa rede propria dentro da maquina, ficando a 2 saltos,
# entao a resposta nao chegava ate eles (erro "Unable to locate credentials").
#
# A solucao:
# Aumentar o limite de saltos para 2, mantendo o IMDSv2 obrigatorio
# (http_tokens = "required"), que e a versao mais segura do IMDS.
resource "aws_launch_template" "nodes" {
  name_prefix = "${var.project_name}-nodes-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }
}

# O grupo de maquinas onde os containers vao rodar
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"

  # Usa o molde acima, para as maquinas ja nascerem com o limite de 2 saltos
  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_count
    min_size     = 1
    max_size     = var.node_count
  }
}
