## Deployment Flow

### 1. Provision Infrastructure and Deploy Applications

Run the following command from the Terragrunt root directory:

terragrunt run-all apply

This will create all infrastructure components and deploy all applications across environments.

**Deployment Process (Step-by-Step)**:
When I run terragrunt run-all apply, Terragrunt orchestrates the deployment of all resources in my environment according to the dependency graph defined in the configuration.

- Root Configuration (root.hcl)
Terragrunt first loads the global configuration, including remote state backend (S3), state locking (DynamoDB), and shared variables. At this stage, no actual resources are created - it only sets up where state will be stored.

- providers.tf:
Terraform collects all required_providers from:
The root module
All child modules (recursively)
Terraform downloads and installs the providers locally (in .terraform/plugins/).
This is important: it doesn’t install anything on AWS, Kubernetes, or Helm itself.
It just makes the plugins available for Terraform to talk to the remote systems.
**Before applying any resources, Terraform ensures:**
All required providers are installed
Correct versions are used
Modules then use these providers:
If i try to apply a module that needs a provider (like Kubernetes or Helm) without the system knowing this providers exists and ready to install them, Terraform will fail
This prevents you from “running on a cluster without the provider configured”
**Terraform forces you to declare providers first, ensuring that no module runs against a system (AWS, Kubernetes, Helm, etc.) before Terraform has the necessary plugin ready.**

Make them available to all modules that reference them
- Environment-Specific Config (root/live/{dev,prod}/terragrunt.hcl)
Terragrunt scans the environment folder and builds a dependency graph between modules. Each module knows which outputs from other modules it requires. Providers (AWS, Kubernetes, Helm) are initialized, and module sources are downloaded.

- VPC Module
The VPC module runs first to create the networking layer: VPC, subnets (public/private), route tables, IGW, NAT Gateway, and security groups. Its outputs (VPC ID, subnet IDs) are required by other modules like EKS.

- EKS Module
The EKS module waits for VPC outputs, then creates the EKS cluster (control plane), managed node groups, and add-ons. Kubernetes and Helm providers are initialized only after the cluster endpoint and token are available (data.aws_eks_cluster_auth).

- IAM Roles / IRSA
IAM policies and IRSA roles are created next. Each pod that needs AWS permissions (e.g., S3 access, Load Balancer management) gets a dedicated IAM role linked to a ServiceAccount. These roles depend on the cluster’s OIDC provider and cannot be fully attached until the cluster is active.

- Kubernetes Resources
Namespaces and ServiceAccounts are created in the cluster. Helm charts that require these ServiceAccounts (like the AWS Load Balancer Controller) are installed afterward so that the pods get the correct AWS permissions via IRSA.

- ArgoCD and Application Deployment
Finally, ArgoCD is deployed via Helm and configured to sync applications from Git repositories. ArgoCD fetches the repo, renders manifests, and applies them to the cluster (auto-sync if enabled). This ensures all applications are up to date in the cluster.

- Completion
Once all modules are applied in the correct order, I verify the deployment with commands like kubectl get nodes, kubectl get pods -A, helm list -n kube-system, and terragrunt output-all.

**more info about the proccess of irsa + oidc + boto3 + alb**:
When you create an EKS cluster with enable_irsa = true, an OIDC provider is automatically created. This allows pods to obtain temporary AWS credentials without using static access keys.
Each pod that requires specific permissions is associated with a custom IAM role. For example:
If pods need to access Secrets Manager or S3, you create an IAM role with the appropriate policy.
If pods need to manage a Load Balancer, you create a different IAM role with the required permissions.
The IAM role is then linked to a ServiceAccount, and each ServiceAccount is assigned to one pod or a group of pods. Once a pod uses that ServiceAccount, it can operate under the permissions defined in the IAM role through OIDC.
In the case of the Flask app, the code inside the pod uses boto3 – the AWS SDK for Python – which allows the pod to perform actions in AWS, such as creating an S3 bucket or retrieving secrets. All of this is done under the permissions provided by the IAM role linked to the ServiceAccount.
Additionally, system pods running in the kube-system namespace, such as the ALB Ingress Controller, watch for Ingress resources like ingress.yaml. When an Ingress resource is applied, the ALB controller automatically provisions an Application Load Balancer (ALB) and updates the DNS/endpoint. This ensures that external traffic can reach the correct service in the cluster using the ALB address.
This setup ensures that permissions and pods are securely and centrally managed through OIDC and IRSA, while traffic is properly routed through the ALB managed by the ingress controller.

**This command is meant to update your kubeconfig file (usually ~/.kube/config) so that you can connect to your EKS cluster using kubectl:**
aws eks update-kubeconfig --name dev-eks-cluster --region us-east-1 
**or in the other cluster:**
aws eks update-kubeconfig --name prod-eks-cluster --region us-east-1

**Post-Deployment Verification**
**Access ArgoCD UI**
# Show initial password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode

# Port-forward ArgoCD to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

Username: admin
Local port: 8080 → ArgoCD server port 443
Namespace: argocd


**Verify Cluster Health and Workloads**:
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

**Verify Load Balancer Address**:
kubectl get ingress flask-ingress -n staging -w (to look for the app in browser add http:// to alb address)

