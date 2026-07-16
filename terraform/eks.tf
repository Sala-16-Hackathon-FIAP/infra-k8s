# eks.tf — Compatible with AWS Academy (uses pre-existing LabRole, no module)

resource "aws_eks_cluster" "main" {
  name     = "fiapx-cluster"
  role_arn = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  version  = "1.31"

  vpc_config {
    subnet_ids             = [aws_subnet.public.id, aws_subnet.private_a.id, aws_subnet.private_b.id]
    endpoint_public_access = true
  }

  depends_on = [aws_vpc.main]
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "fiapx-nodes"
  node_role_arn   = "arn:aws:iam::${var.aws_account_id}:role/LabRole"
  subnet_ids      = [aws_subnet.public.id]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [aws_eks_cluster.main]
}
