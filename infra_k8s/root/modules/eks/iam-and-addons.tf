# ---- IAM Policy ל-Flask App ----
resource "aws_iam_policy" "flask_app_policy" {
  name        = "prod-flask-app-policy"
  description = "Permissions for Flask App to access Secrets Manager and S3 via IRSA"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:flask-app-secret-*"
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket", "s3:PutObjectAcl"]
        Resource = [
          "arn:aws:s3:::my-second-hand-clothes-storage",
          "arn:aws:s3:::my-second-hand-clothes-storage/*"
        ]
      }
    ]
  })
}

# ---- IAM Role ל-IRSA ----
resource "aws_iam_role" "flask_app_irsa_role" {
  name = "prod-flask-app-irsa-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:prod:flask-app-sa"
          }
        }
      }
    ]
  })

  depends_on = [
    module.eks
  ]
}

# ---- IAM Role Policy Attachment ----
resource "aws_iam_role_policy_attachment" "flask_app_attach" {
  role       = aws_iam_role.flask_app_irsa_role.name
  policy_arn = aws_iam_policy.flask_app_policy.arn
}

# ---- Kubernetes Service Account ל-Flask App ----
resource "kubernetes_service_account" "flask_app_sa" {
  metadata {
    name      = "flask-app-sa"
    namespace = "prod"

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.flask_app_irsa_role.arn
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.flask_app_attach,
    kubernetes_namespace.prod
  ]
}
