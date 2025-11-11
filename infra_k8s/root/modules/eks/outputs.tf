output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster CA data"
  value       = module.eks.cluster_certificate_authority_data
}


output "oidc_issuer_url" {
  description = "The URL of the cluster's OIDC issuer"
  value       = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}



output "cluster_token" {
  description = "Authentication token for the EKS cluster"
  value       = data.aws_eks_cluster_auth.this.token
  sensitive = true
}

output "self_signed_certificate_arn" {
  description = "The ARN of the self-signed certificate in ACM"
  value       = aws_acm_certificate.self_signed_cert.arn
}