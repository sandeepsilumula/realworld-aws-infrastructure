# ==========================================
# 1. CORE NETWORK TIER (VPC)
# ==========================================
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1" # Modern VPC version supporting isolated subnets natively

  name = "enterprise-production-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]  
  public_subnets  = ["10.0.10.0/24", "10.0.20.0/24"] 

  enable_nat_gateway = true
  single_nat_gateway = true # Limits dev runtime costs

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# ==========================================
# 2. FIREWALL LAYER (SECURITY GROUPS)
# ==========================================
resource "aws_security_group" "alb_sg" {
  name        = "production-alb-sg"
  description = "Edge firewall accepting public web traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Allow public HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic globally"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "production-ec2-sg"
  description = "Isolate application nodes from direct internet exposure"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Restrict HTTP traffic strictly to Load Balancer ingress rules"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] 
  }

  egress {
    description = "Allow secure package downloads and internet patching updates"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "production-rds-sg"
  description = "Isolate database cluster from edge vectors"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Allow database queries strictly from valid compute tier nodes"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] 
  }

  egress {
    description = "Isolate database completely from outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 3. EDGE DELIVERY TIER (ALB)
# ==========================================
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.9.0" # Modern ALB module using structured object maps

  name = "portfolio-production-alb"

  enable_deletion_protection = false

  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb_sg.id]

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "web_fleet"
      }
    }
  }

  target_groups = {
    web_fleet = {
      name_prefix      = "prod-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      vpc_id           = module.vpc.vpc_id
      create_attachment = false # <--- ADD THIS LINE: Tells the module NOT to look for target_ids!
      
      health_check = {
        enabled             = true
        path                = "/"
        port                = "80"
        protocol            = "HTTP"
        interval            = 15
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }
    }
  }
}


# ==========================================
# 4. COMPUTE FLEET TIER (NATIVE AUTO SCALING)
# ==========================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Standard modern AWS Linux Operating System image
  }
}

resource "aws_launch_template" "web_template" {
  name_prefix   = "production-launch-template-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to My Production Portfolio Website</h1><p>Deploy Complete! Infrastructure core is online and healthy.</p>" > /var/www/html/index.html
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name_prefix         = "production-asg-"
  vpc_zone_identifier = module.vpc.private_subnets 

  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  # Modern syntax: Wires instances seamlessly into the ALB module target group output
  target_group_arns = [module.alb.target_groups["web_fleet"].arn]

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }

  health_check_type         = "ELB" 
  health_check_grace_period = 300

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# 5. STORAGE TIER (RDS DATABASE CLUSTER)
# ==========================================
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "production-rds-subnet-group-v3"
  description = "Isolates database instances inside private subnets"
  subnet_ids  = module.vpc.private_subnets
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.6.0"

  identifier = "portfolio-production-db"

  deletion_protection = false

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "portfoliodb"
  username = "admin"
  password = var.db_password
  
  # ✅ FIX LINE: Tells the module NOT to try and create an AWS Secrets Manager secret
  manage_master_user_password = false 

  port                   = 3306
  multi_az               = false
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
}

# =============================================================
# 6. SRE TELEMETRY LAYER (AWS CLOUDWATCH METRICS DASHBOARD)
# =============================================================

resource "aws_cloudwatch_dashboard" "ser_dashnoard" {
    dashboard_name = "Enterprise-System-Health-Telemetry"

    dashboard_body = jsonencode({
        widgets = [
            {
                type = "metric"
                x    = 0
                y    = 0
                width = 12
                height = 6
                properties = {
                    metrics = [
                        ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.web_asg.name}"]
                    ]
                period = 60
                stat   = "Sum"
                region = "us-east-1"
                title  = "🌐 Gateway Layer: Total Inbound Traffic (Request Count)"
                view   = "timeSeries"
                stacked = false
        }
        
    },
            {
                type = "metric"
                x    = 12
                y    = 0
                width = 12
                height = 6
                properties = {
                    metrics = [
                        ["AWS/RDS", "DBConnections", "DBInstanceIdentifier", "${module.db.db_instance_identifier}"]
                    ]
                    period = 60
          stat   = "Average"
          region = "us-east-1"
          title  = "🗄️ Storage Tier: Active Database Connection Pools"
          view   = "timeSeries"
          stacked = false
        }
      }
    ]
  })
}
           
  
