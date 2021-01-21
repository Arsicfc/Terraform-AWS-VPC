# Specify Provider which cloud you are using.
provider "aws" {
  region     = "us-east-1"
}

# Create VPC
resource "aws_vpc" "Terraform_vpc" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "Terraform_vpc"
  }
}

#variable "subnet_prefix" {
#    description= "Cidr Value"

  
#}
# Create Subnet
resource "aws_subnet" "Terraform_subnet" {
  vpc_id            = aws_vpc.Terraform_vpc.id
  cidr_block = "172.16.10.0/24"
  #cidr_block        = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"

  tags = {
    Name = "Terraform_subnet" 
    #Name = var.subnet_prefix[0].name
  }
}

#resource "aws_subnet" "Terraform_subnet2" {
#  vpc_id            = aws_vpc.Terraform_vpc.id
#  cidr_block        = var.subnet_prefix[1].cidr_block
#  availability_zone = "us-east-1a"

#  tags = {
#    Name = var.subnet_prefix[1].name
#  }
#}
# Create Internet Gateway
resource "aws_internet_gateway" "Terraform-gateway" {
  vpc_id = aws_vpc.Terraform_vpc.id

  tags = {
    Name = "Terraform-gateway"
  } 
}
# Create Custom Route Table
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.Terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Terraform-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.Terraform-gateway.id
  }

  tags = {
    Name = "route"
  }
}
#Associate subnet with route table
resource "aws_route_table_association" "route-table" {
  subnet_id      = aws_subnet.Terraform_subnet.id
  route_table_id = aws_route_table.route-table.id
}
#Create Security Group
resource "aws_security_group" "security-group" {
  name        = "security-group"
  description = "Allow-web-traffic"
  vpc_id      = aws_vpc.Terraform_vpc.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    ingress {
    description = "HTTPS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins from VPC"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
#Create Network Interface
resource "aws_network_interface" "nic" {
  subnet_id       = aws_subnet.Terraform_subnet.id
  private_ips     = ["172.16.10.50"] #Ip of Server
  security_groups = [aws_security_group.security-group.id]
}
#Associate Elastic IP (Public IP to server)
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.nic.id
  associate_with_private_ip = "172.16.10.50"
  depends_on = [aws_internet_gateway.Terraform-gateway] # Need to make gateway before deploying EIP
}
#Create Apache webserver Ubuntu
#Creating Instance
resource "aws_instance" "Test-Terraform"  {
  ami           = "ami-0885b1f6bd170450c" 
  instance_type = "t2.micro"
  availability_zone = "us-east-1a" #same as subnet
  key_name = "server-key"


    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.nic.id

    }
    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y 
                sudo apt install -y default-jre
                wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
                sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
                sudo apt-get update 
                sudo apt-get install jenkins 
                sudo systemctl start jenkins
                #sudo apt install apache2 -y
                #sudo systemctl start apache2
                #sudo bash -c 'echo my webserver> /var/www/html/index.html'
                EOF
    tags = {
        Name = "Test-Server"
    }
 
}