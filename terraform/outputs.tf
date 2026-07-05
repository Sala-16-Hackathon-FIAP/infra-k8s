output "cluster_name" {
  description = "EKS cluster name — configure kubectl in CI pipelines"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority" {
  description = "EKS cluster CA certificate (base64)"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr_block" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_a_id" {
  description = "Private subnet A (us-east-1a) — used for RDS"
  value       = aws_subnet.private_a.id
}

output "private_subnet_b_id" {
  description = "Private subnet B (us-east-1b) — used for RDS HA"
  value       = aws_subnet.private_b.id
}

output "s3_videos_bucket_name" {
  description = "S3 bucket name for video uploads and processed frames"
  value       = aws_s3_bucket.videos.bucket
}
