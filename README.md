# 🚀 Enterprise-Grade Three-Tier AWS Cloud Architecture with GitOps CI/CD

An automated, highly available, and production-ready **Three-Tier Cloud Infrastructure Grid** built on AWS using **Infrastructure as Code (IaC)** with Terraform. This project features robust SRE observability tracking and an entirely automated **GitHub Actions CI/CD GitOps workflow** representing modern corporate platform engineering standards.

## 📐 System Architecture Diagram

```html
<pre style="background: #0f172a; color: #38bdf8; padding: 20px; border-radius: 12px; border: 1px solid #334155; font-family: monospace; font-size: 13px; line-height: 1.5; overflow-x: auto;">
                 [ 🌐 Public Internet Users ]
                              │
                              ▼
       Edge Delivery: Application Load Balancer (ALB)
                              │
                ┌─────────────┴─────────────┐
                ▼ (AZ 1a)                   ▼ (AZ 1b)
      ┌───────────────────────────┐┌───────────────────────────┐
      │  🛡️ Public Subnet         ││  🛡️ Public Subnet         │
      │   [NAT Gateway Routing]   ││   [Backup Route Tables]   │
      └─────────┬─────────────────┘└─────────┬─────────────────┘
                │                            │
                ▼ (Private VPC Ingress Only) ▼
      ┌───────────────────────────┐┌───────────────────────────┐
      │  🔒 Private Subnet        ││  🔒 Private Subnet        │
      │   💻 Compute Instance Node││   💻 Compute Instance Node│
      │      (Apache Web Tier)    ││      (Apache Web Tier)    │
      └─────────┬─────────────────┘└─────────┬─────────────────┘
                │                            │
                └─────────────┬──────────────┘
                              ▼ (Strict Ingress Port 3306)
      ┌────────────────────────────────────────────────────────┐
      │  🗄️ Isolated Storage Subnet Tier                        │
      │   🔑 Amazon RDS MySQL Relational Database Cluster      │
      └────────────────────────────────────────────────────────┘
</pre>


## 🌟 Key Infrastructure & Engineering Pillars

### 1. Networking Perimeter (VPC Tier)
* Designed a custom Virtual Private Cloud (VPC) with non-overlapping `10.0.0.0/16` CIDR block boundaries.
* Partitioned network across multi-AZ configurations (`us-east-1a` & `us-east-1b`) for high-availability constraints.
* Enforced structural network division separating Internet-facing public load-balancing subnets from dark private subnets holding compute instances and database backends.

### 2. High Availability & Compute Fleet (ASG)
* Native **AWS Auto Scaling Group (ASG)** handles automated instance provisioning dynamically (`Min: 2, Max: 4`).
* Compute instances are bootstrapped automatically on boot using user data shell scripts running the web application framework cleanly.
* Multi-AZ distribution ensures complete resilience against physical underlying AWS data center physical failures.

### 3. Edge Delivery & Zero Trust Firewalls (ALB & Security Groups)
* An **Application Load Balancer (ALB)** exposes a single, safe public address to handle incoming customer request volumes, serving as the gatekeeper.
* Implemented strict **Security Group Chaining**:
  * `ALB Security Group`: Publicly accepts web requests via TCP Port 80.
  * `EC2 Security Group`: Dropped direct public exposure. Selectively accepts routing flows *only* from the ALB's unique firewall signature.
  * `RDS Security Group`: Total edge isolation. Evaluates incoming paths and blocks everything unless requested via Port 3306 by a verified application server.

### 4. Site Reliability Engineering (SRE) Observability Dashboard
* Deployed native **AWS CloudWatch Dashboards** representing complete real-time platform metrics.
* Features automated dashboard configurations tracing three critical system vectors:
  * 🚀 **Compute Fleet Average CPU Utilization (%)**
  * 🌐 **Edge Dynamic Request Delivery Footprints (ALB Request Count)**
  * 🗄️ **Storage Engine Active Connection Pools (RDS Instance Metrics)**

### 5. GitOps Pipeline & Continuous Integration (GitHub Actions)
* Complete hands-off operations. Built an automated **CI/CD infrastructure lifecycle deployment pipeline**.
* Leverages GitHub's Encrypted Hardware Vault to handle `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `DB_PASSWORD` parameters safely.
* The workflow pipeline checks semantic syntax, enforces standard code formatting via linters, tests configuration maps, and runs zero-click rollouts to live environments securely on every git push code update.

---

## 🛠️ File Structure Matrix

* 📂 **`.github/workflows/`** — Continuous Integration Core Workspace Directory
  * 📄 `deploy-pipeline.yml` — Automated GitOps Actions CI/CD Pipeline Workflow Script
* 📄 **`main.tf`** — Master Multi-Tier Production Infrastructure Topology Declarations
* 📄 **`providers.tf`** — Pins Underlying HashiCorp Engine Plugins to Verified Stable AWS 5.x
* 📄 **`variables.tf`** — Isolates and Declares Sensitive Infrastructure Runtime Configurations
* 📄 **`outputs.tf`** — Extracts and Displays Operational Runtime Values Post Deployment Passes
* 📄 **`README.md`** — Comprehensive Architectural Technical Summary Documentation

## docs: convert directory structure map to high-visibility clean layout list
