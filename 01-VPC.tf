
# VPC
resource "aws_vpc" "chatapp-vpc" {
  cidr_block       = "10.0.0.0/20"
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "chatapp vpc"
  }
}
