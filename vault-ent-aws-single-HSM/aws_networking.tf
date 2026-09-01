#######################
#      Networking     #
#######################
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.prefix}-vpc"
  }
}

# SECURITY GROUPS
resource "aws_security_group" "public" {
  name        = "${var.prefix}_public_sg"
  description = "Allow inbound https and ssh. Allow all outbound traffic"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_vault_public" {
  for_each          = aws_eip.public
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 8200
  to_port           = 8200
  ip_protocol       = "tcp"
}

# Both ports 8200 and 8201 for vault API and cluster communication
resource "aws_vpc_security_group_ingress_rule" "allow_vault_external_vpc" {
  for_each          = var.allowed_cidrs
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = each.value
  from_port         = 8200
  to_port           = 8201
  ip_protocol       = "tcp"
}

# These ingress rules allows SSH access only from allowed office and private
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  for_each          = var.allowed_cidrs
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "allow_egress_public" {
  security_group_id = aws_security_group.public.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Internet access to VPC:
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

data "aws_availability_zone" "target" {
  name = "${var.region}a"
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr
  region            = var.region
  availability_zone = data.aws_availability_zone.target.name
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

#######################
#     Public IPs      #
#######################

resource "aws_eip" "public" {
  for_each = var.vms_info
  instance = aws_instance.node[each.key].id
  domain   = "vpc"
}