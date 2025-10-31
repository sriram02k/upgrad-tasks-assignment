provider "aws" {
  region = "us-east-1"
}


#Defining Variables with the values as requested

variable "vpc_cidr" {
  default = "10.10.0.0/16"
}

variable "pub_a_cidr" {
  default = "10.10.1.0/24"
}

variable "pub_b_cidr" {
  default = "10.10.2.0/24"
}

variable "pri_a_cidr" {
  default = "10.10.3.0/24"
}

variable "pri_b_cidr" {
  default = "10.10.4.0/24"
}


#Creates the VPC "main" with desired cidr

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}


#Creates IGW 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw"
  }
}


#Creates two Public Subnets- pub_a & pub_b

resource "aws_subnet" "pub_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub_a_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub-a"
  }
}

resource "aws_subnet" "pub_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.pub_b_cidr
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "pub-b"
  }
}


#Elastic IP (for NAT)

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}


#Creating NAT Gateway

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.pub_a.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]
}


#Creating two Private Subnets- pri_a & pri_b

resource "aws_subnet" "pri_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pri_a_cidr
  availability_zone = "us-east-1a"

  tags = {
    Name = "pri-a"
  }
}

resource "aws_subnet" "pri_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.pri_b_cidr
  availability_zone = "us-east-1b"

  tags = {
    Name = "pri-b"
  }
}


#Creates public route table 

resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "pub-rt"
  }
}

#Associating  public RT with both public subnets
resource "aws_route_table_association" "pub_a_assoc" {
  subnet_id      = aws_subnet.pub_a.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_route_table_association" "pub_b_assoc" {
  subnet_id      = aws_subnet.pub_b.id
  route_table_id = aws_route_table.pub_rt.id
}


#Creating  Private Route Table

resource "aws_route_table" "pri_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "pri-rt"
  }
}

#Associating Private RT with both private subnets
resource "aws_route_table_association" "pri_a_assoc" {
  subnet_id      = aws_subnet.pri_a.id
  route_table_id = aws_route_table.pri_rt.id
}

resource "aws_route_table_association" "pri_b_assoc" {
  subnet_id      = aws_subnet.pri_b.id
  route_table_id = aws_route_table.pri_rt.id
}