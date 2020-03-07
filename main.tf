provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = "true"
    tags = {
      Name = "my_vpc"
    }
}

resource "aws_subnet" "public1" {
  vpc_id = "vpc-0b87861931fdf6587"
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"

  tags = {
          Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public2"{
        vpc_id = "vpc-0b87861931fdf6587"
        cidr_block = "10.0.2.0/24"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1b"

        tags = {
                Name = "Public Subnet 2"
        }
}

resource "aws_subnet" "private1"{
        vpc_id = "vpc-0b87861931fdf6587"
        cidr_block = "10.0.1.0/24"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1a"

        tags = {
                Name = "Private Subnet 1"
        }
}

resource "aws_subnet" "private2"{
        vpc_id = "vpc-0b87861931fdf6587"
        cidr_block = "10.0.3.0/24"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1b"

        tags = {
                Name = "Private Subnet 2"
        }
}

resource "aws_internet_gateway" "IGW" {
	vpc_id = "vpc-0b87861931fdf6587"

	tags = {
		Name = "VPC IGW"
	}
}

resource "aws_route_table" "public" {
  vpc_id = "vpc-0b87861931fdf6587"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "igw-0073aa5691dde4e3e"
  }

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_route_table_association" "Public-1" {
  subnet_id = "subnet-0ff5be50865c65600"
  route_table_id = "rtb-0267b0000e52afb93"
}

resource "aws_route_table_association" "Public-2" {
  subnet_id = "subnet-02a93ec52de3c0576"
  route_table_id = "rtb-0267b0000e52afb93"
}

#Creating NAT instance for ssh bastion

resource "aws_security_group" "nat" {
  name = "vpc_nat"
  description = "Allow traffic to pass from the private subnets to the internet"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.3.0/24"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  vpc_id = "vpc-0b87861931fdf6587"

  tags = {
    Name = "nat_sg"
  }


}

resource "aws_instance" "nat" {
  ami = "ami-00a9d4a05375b2763" #special ami for nat instance
  availability_zone = "us-east-1a"
  instance_type = "t2.micro"
  key_name = "terra" #this is to be adjusted accordingly
  vpc_security_group_ids = ["sg-0ff94806c4d305ae2"]
  subnet_id = "subnet-0ff5be50865c65600"
  associate_public_ip_address = true
  source_dest_check = false

  tags= {
    Name = "VPC NAT"
  }
}

resource "aws_route_table" "Private" {
  vpc_id = "vpc-0b87861931fdf6587"

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "i-091fab883d5835829"
  }

  tags= {
    Name = "Private Subnet"
  }
}

resource "aws_route_table_association" "Private" {
  subnet_id = "subnet-09622527bfae7964f"
  route_table_id = "rtb-06eac8546fc578288"
}

#Security Group for Web Server

resource "aws_security_group" "web" {
	name = "vpc_web"
	description = "Allow incoming HTTP connections"

	ingress {
		from_port = 80
		to_port = 80
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

  ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}

  ingress {
		from_port = 3306
		to_port = 3306
		protocol = "tcp"
		cidr_blocks = ["10.0.1.0/24", "10.0.3.0/24"]
	}


  egress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24", "10.0.3.0/24"]
  }

  vpc_id = "vpc-0b87861931fdf6587"


	tags= {
		Name = "Web Server SG"
	}
}

#launching webserver in public2 subnet

resource "aws_instance" "web_server" {
  ami = "ami-0a887e401f7654935"
  availability_zone = "us-east-1b"
  instance_type = "t2.micro"
  key_name = "terra"
  vpc_security_group_ids = ["sg-0855268754d87eb18"]
  subnet_id = "subnet-02a93ec52de3c0576"
  associate_public_ip_address = true
  source_dest_check = false

  tags= {
    Name = "Web Server 1"
  }
}

#SG for RDS
resource "aws_security_group" "mydb" {
  name = "mydb"

  description = "RDS mysql servers (terraform-managed)"
  vpc_id = "vpc-0b87861931fdf6587"

  # Only postgres in
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = ["sg-0855268754d87eb18"]
  }
}

#Create DB subnet group so we can host db in both private subnets
resource "aws_db_subnet_group" "db-subnet" {
  name       = "db-subnet"
  subnet_ids = ["subnet-09622527bfae7964f", "subnet-004bb2e7ad4c4869e"]

  tags = {
    Name = "My DB subnet group"
  }
}

#create RDS instance
resource "aws_db_instance" "mydb1" {
  allocated_storage        = 20 # gigabytes
  db_subnet_group_name     = "db-subnet"
  engine                   = "mysql"
  engine_version           = "5.7.22"
  identifier               = "lab-db"
  instance_class           = "db.t2.micro"
  name                     = "mydb1"
  username                 = "" # I emptied it before I push this code
  password                 = "" # I emptied it before I push this code
  port                     = 3306
  publicly_accessible      = false
  storage_type             = "gp2"
  vpc_security_group_ids   = ["sg-0cbfb33ee2153cd88"]
  backup_retention_period  = 0
  monitoring_interval      = 0
}
