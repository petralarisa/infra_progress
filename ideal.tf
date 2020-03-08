provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_hostnames = "true"
    tags = {
      Name = "my_vpc"
    }
}

resource "aws_subnet" "public1" {
  vpc_id = "aws_vpc.my_vpc.id"
  cidr_block = "192.168.40.0/21"
  availability_zone = "us-east-1a"

  tags = {
          Name = "Public Subnet 1"
  }
}

resource "aws_subnet" "public2"{
        vpc_id = "aws_vpc.my_vpc.id"
        cidr_block = "192.168.48.0/21"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1b"

        tags = {
                Name = "Public Subnet 2"
        }
}

resource "aws_subnet" "private1"{
        vpc_id = "aws_vpc.my_vpc.id"
        cidr_block = "192.168.0.0/20"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1a"

        tags = {
                Name = "Private Subnet 1"
        }
}

resource "aws_subnet" "private2"{
        vpc_id = "aws_vpc.my_vpc.id"
        cidr_block = "192.168.16.0/20"
        map_public_ip_on_launch = "true"
        availability_zone = "us-east-1b"

        tags = {
                Name = "Private Subnet 2"
        }
}

resource "aws_internet_gateway" "IGW" {
	vpc_id = "aws_vpc.my_vpc.id"

	tags = {
		Name = "VPC IGW"
	}
}

resource "aws_route_table" "public" {
  vpc_id = "aws_vpc.my_vpc.id"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "aws_internet_gateway.IGW.id"
  }

  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_route_table_association" "Public-1" {
  subnet_id = "aws_subnet.public1.id"
  route_table_id = "aws_route_table.public.id"
}

resource "aws_route_table_association" "Public-2" {
  subnet_id = "aws_subnet.public2.id"
  route_table_id = "aws_route_table.public.id"
}

#Creating NAT instance for ssh bastion

resource "aws_security_group" "nat" {
  name = "vpc_nat"
  description = "Allow traffic to pass from the private subnets to the internet"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["192.168.0.0/20", "192.168.16.0/20"]
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


  vpc_id = "aws_vpc.my_vpc.id"

  tags = {
    Name = "nat_sg"
  }


}

resource "aws_instance" "nat" {
  ami = "ami-00a9d4a05375b2763" #special ami for nat instance
  availability_zone = "us-east-1a"
  instance_type = "t2.micro"
  key_name = "terra" #this is to be adjusted accordingly
  vpc_security_group_ids = ["aws_security_group.nat.id"]
  subnet_id = "aws_subnet.public1.id"
  associate_public_ip_address = true
  source_dest_check = false

  tags= {
    Name = "VPC NAT"
  }
}

resource "aws_route_table" "Private" {
  vpc_id = "aws_vpc.my_vpc.id"

  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "aws_instance.nat.id"
  }

  tags= {
    Name = "Private Subnet"
  }
}

resource "aws_route_table_association" "Private" {
  subnet_id = "aws_subnet.private1.id"
  route_table_id = "aws_route_table.private.id"
}

resource "aws_route_table_association" "Private2" {
  subnet_id = "aws_subnet.private2.id"
  route_table_id = "aws_route_table.Private.id"
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
		cidr_blocks = ["192.168.0.0/20", "192.168.16.0/20"]
	}


  egress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["192.168.0.0/20", "192.168.16.0/20"]
  }

  vpc_id = "aws_vpc.my_vpc.id"


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
  vpc_security_group_ids = ["aws_security_group.web.id"]
  subnet_id = "aws_subnet.public2.id"
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
  vpc_id = "aws_vpc.my_vpc.id"

  # Only postgres in
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = ["aws_security_group.web.id"]
  }
}

#Create DB subnet group so we can host db in both private subnets
resource "aws_db_subnet_group" "db-subnet" {
  name       = "db-subnet"
  subnet_ids = ["aws_subnet.private1.id", "aws_subnet.private2.id"]

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
  vpc_security_group_ids   = ["aws_security_group.mydb.id"]
  backup_retention_period  = 0
  monitoring_interval      = 0
}
