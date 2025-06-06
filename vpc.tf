
# VPC
resource "aws_vpc" "chatApp-vpc" {
  cidr_block       = "10.0.0.0/20"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "chatApp vpc"
  }
}

# SUBNETS
resource "aws_subnet" "chatApp-public-subnet-2a" {
  vpc_id     = aws_vpc.chatApp-vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"
  tags = {
    Name = "chatApp public-subnet-2a"
  }
}

resource "aws_subnet" "chatApp-private-subnet-2a" {
  vpc_id     = aws_vpc.chatApp-vpc.id
  cidr_block = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-2a"
  tags = {
    Name = "chatApp private-subnet-2a"
  }
}

# INTERNET GATEWAY
resource "aws_internet_gateway" "chatApp-IGW" {
  vpc_id = aws_vpc.chatApp-vpc.id
  tags = {
    Name = "chatApp IGW"
  }
}
# Elastic-Ip for NAT
resource "aws_eip" "chatApp_eip" {
  vpc = true
  tags = {
    Name = "chatApp NAT EIP"
  }
}
# NAT gateway with Elastic IP
resource "aws_nat_gateway" "chatApp-nat" {
  allocation_id = aws_eip.chatApp_eip.id
  subnet_id     = aws_subnet.chatApp-public-subnet-2a.id

  tags = {
    Name = "chatApp NAT Gateway"
  }
  depends_on = [aws_internet_gateway.chatApp-IGW]
}




# ROUTE TABLES

# Public-RT
resource "aws_route_table" "chatApp-vpc-public-RT" {
  vpc_id = aws_vpc.chatApp-vpc.id

  route {
    cidr_block           = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.chatApp-IGW.id
  }

  tags = {
    Name = "chatApp-vpc public-RT"
  }
}

# Private-RT
resource "aws_route_table" "chatApp-vpc-private-RT" {
  vpc_id = aws_vpc.chatApp-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.chatApp-nat.id
  }

  tags = {
    Name = "chatApp-vpc private-RT"
  }
}



# SUBNET - ROUTE TABLE ASSOCIATION -PUBLIC
resource "aws_route_table_association" "chatApp-public-asc-2a" {
  subnet_id      = aws_subnet.chatApp-public-subnet-2a.id
  route_table_id = aws_route_table.chatApp-public-RT.id
}

resource "aws_route_table_association" "chatApp-private-asc-2a" {
  subnet_id      = aws_subnet.chatApp-private-subnet-2a.id
  route_table_id = aws_route_table.chatApp-vpc-private-RT.id
}



# Security Groups

# NGINX-Security Group
resource "aws_security_group" "chatApp-public-SG" {
  name        = "chatApp-vpc ALL-SG"
  description = "Allow all inbound traffic"
  vpc_id      = aws_vpc.chatApp-vpc.id

  ingress {
    description = "SSH from WWW"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from WWW"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from WWW"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # ingress {
  #   description      = "Allow all inbound traffic"
  #   from_port        = 0
  #   to_port          = 0
  #   protocol         = "-1"  # -1 means all protocols
  #   cidr_blocks      = ["0.0.0.0/0"]  # from anywhere
  # }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "chatApp public-SG"
  }
}

resource "aws_security_group" "chatApp-private-SG" {
  name        = "chatApp private-SG"
  description = "Allow SSH from public subnet EC2 only"
  vpc_id      = aws_vpc.chatApp-vpc.id

  ingress {
    description = "Allow SSH from specific internal host"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.10/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Internet via NAT Gateway
  }

  tags = {
    Name = "chatApp private SG"
  }
}


# 1. Create IAM Role
resource "aws_iam_role" "chatApp-ec2-role" {
  name = "chatApp ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# 2. Attach AdministratorAccess Policy to Role
resource "aws_iam_role_policy_attachment" "chatApp-ec2-role-admin-access" {
  role       = aws_iam_role.chatApp-ec2-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 3. Create IAM Instance Profile
resource "aws_iam_instance_profile" "chatApp-ec2-instance-profile" {
  name = "chatApp ec2-instance-profile"
  role = aws_iam_role.chatApp-ec2-role.name
}

# 4. Attach IAM Instance Profile to EC2 instance
resource "aws_instance" "chatApp-NGINX" {
  ami                    = "ami-0d0f28110d16ee7d6"
  instance_type          = "t2.medium"
  key_name               = "devops_1"
  vpc_security_group_ids = [aws_security_group.chatApp-public-SG.id]
  private_ip             = "10.0.1.10"
  subnet_id              = aws_subnet.chatApp-public-subnet-2a.id
  iam_instance_profile   = aws_iam_instance_profile.chatApp-ec2-instance-profile.name

  metadata_options {
    http_tokens = "optional"
  }

  user_data = <<-EOF
                #!/bin/bash
                yum -y update
                yum -y install git
                yum -y install nginx
                systemctl start nginx
                systemctl enable nginx
            EOF

  tags = {
    Name = "chatApp NGINX"
  }
}

resource "aws_instance" "chatApp-K8s-workstation" {
  ami                    = "ami-0d0f28110d16ee7d6"
  instance_type          = "t2.medium"
  key_name               = "devops_1"
  vpc_security_group_ids = [aws_security_group.chatApp-Private-SG.id]
  private_ip             = "10.0.2.10"
  subnet_id              = aws_subnet.chatApp-private-subnet-2a.id
  iam_instance_profile   = aws_iam_instance_profile.chatApp-ec2-instance-profile.name

  metadata_options {
    http_tokens = "optional"
  }

  user_data = <<-EOF
                #!/bin/bash
                yum -y update
                yum -y install git
            EOF

  tags = {
    Name = "chatApp K8s-workstation"
  }
}

# 5. Create S3 Bucket for K8s Store
resource "aws_s3_bucket" "chatApp-k8s-store" {
  bucket = "chatApp-k8s-store"
  force_destroy = true
  tags = {
    Name        = "chatApp k8s-store"
    Environment = "Production"
  }
}



#To automate NGINX and K8s-workstation

output "NGINX_public_ip" {
  value = aws_instance.chatApp-NGINX.public_ip
  description = "Public IP of NGINX-SERVER"
}

# output "k8s_workstation_public_ip" {
#   value = aws_instance.chatApp-K8s-workstation.public_ip
#   description = "Public IP of K8s Workstation"
# }
