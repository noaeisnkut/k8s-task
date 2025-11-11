Hello!

Below is the explanation for the tasks I completed as part of the technical interview.

**Q1 -Jenkins Pipeline Task**

Task Summary:

Create a Jenkins Declarative Pipeline.

Stage 1: Build a containerized application (Python or any other language) on one server.

Stage 2: Deploy the application on a second server as a Kubernetes Pod.

Expose the application externally over HTTPS on port 443.


**My Answer to Q1:**

You can find the full solution in the following structure:

**/app** -contains the application code and the Helm chart used for deployment.

**/infra_k8s** -contains the Terragrunt-based Kubernetes infrastructure (I used this to provision the production cluster).

**Jenkinsfile** -contains the complete Jenkins Declarative Pipeline implementation.


**Q2 - Theoretical Questions**

**My Answer to Q2:**

All responses to the theoretical questions are located in:

**/Theoretical_questions**


**Q3 - Terraform & EC2 Task**

Task Summary:

1. Create a Terraform configuration for a Linux EC2 instance identical to the existing “test ec2” machine, with:

Apache running on port 80

A static Elastic IP

A Security Group allowing inbound traffic only from the Leumi proxy IP: 91.231.246.50


3. Expose this EC2 instance using a Network Load Balancer (NLB).


**My Answer to Q3:**

The full implementation is available in:

**/infra_ec2test**
