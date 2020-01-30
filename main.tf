provider "aws" {
  region = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

data "aws_availability_zones" "available" {}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block = "10.1.0.0/16"
}

#internet gateway

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = "${aws_vpc.vpc.id}"
}

# Route tables

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.internet_gateway.id}"
  }

  tags {
    Name = "public"
  }
}

resource "aws_default_route_table" "private" {
  default_route_table_id = "${aws_vpc.vpc.default_route_table_id}"

  tags {
    Name = "private"
  }
}

resource "aws_subnet" "public1" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "public1"
  }
}


resource "aws_subnet" "private1" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[2]}"

  tags {
    Name = "private2"
  }
}

resource "aws_db_subnet_group" "rds_subnetgroup" {
  name       = "rds_subnetgroup"
  subnet_ids = ["${aws_subnet.private1.id}", "${aws_subnet.private2.id}" ]

  tags {
    Name = "rds"
  }
}





# Subnet Associations

resource "aws_route_table_association" "public1_assoc" {
  subnet_id      = "${aws_subnet.public1.id}"
  route_table_id = "${aws_route_table.public.id}"
}


resource "aws_route_table_association" "private1_assoc" {
  subnet_id      = "${aws_subnet.private1.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private2_assoc" {
  subnet_id      = "${aws_subnet.private2.id}"
  route_table_id = "${aws_route_table.public.id}"
}

#Security groups

resource "aws_security_group" "dev_sg" {
  name        = "dev_sg"
  description = "Used for access to the dev instance"
  vpc_id      = "${aws_vpc.vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "public_sg" {
  name        = "sg_public"
  description = "Used for public and private instances for load balancer access"
  vpc_id      = "${aws_vpc.vpc.id}"

  #SSH

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
#    cidr_blocks = ["${var.localip}"] #change to ${var.localip} if you need specific restriction
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTP

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Outbound internet access

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Private Security Group

resource "aws_security_group" "private_sg" {
  name        = "sg_private"
  description = "Used for private instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  # Access from other security groups

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#RDS Security Group
resource "aws_security_group" "RDS" {
  name        = "sg_rds"
  description = "Used for DB instances"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SQL access from public/private security group

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = ["${aws_security_group.dev_sg.id}", "${aws_security_group.public_sg.id}", "${aws_security_group.private_sg.id}"]
  }
}

#
# key pair

resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

# RDS

resource "random_password" "password" {
  length = 12
  special = true
  override_special = "_%@"
}

resource "aws_db_instance" "db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7.26"
  instance_class         = "${var.db_instance_class}"
  name                   = "${var.dbname}"
  username               = "${var.dbuser}"
  password               = "${random_password.password.result}"
  db_subnet_group_name   = "${aws_db_subnet_group.rds_subnetgroup.name}"
  vpc_security_group_ids = ["${aws_security_group.RDS.id}"]
  skip_final_snapshot    = true
}


# server

resource "aws_instance" "dev" {
  instance_type = "${var.dev_instance_type}"
  ami           = "${var.dev_ami}"

  tags {
    Name = "test-project"
  }

  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.public_sg.id}"]
  subnet_id              = "${aws_subnet.public1.id}"

  provisioner "local-exec" {
    command = <<EOD
cat <<EOF > aws_hosts
[dev]
${aws_instance.dev.public_ip}
EOF
EOD
  }

  provisioner "local-exec" {
    command = <<EOF
    aws ec2 wait instance-status-ok --instance-ids ${aws_instance.dev.id} --profile default  &&
    ansible-playbook -vvv --private-key ~/.ssh/id_rsa -i aws_hosts bootstrap.yml -e "MYSQL_HOST=${aws_db_instance.db.address} MYSQL_USER=${var.dbuser} MYSQL_PASS=${random_password.password.result}"
  EOF
  }

}

#-------OUTPUTS ------------

output " Public Address" {
  value = "${aws_instance.dev.public_ip}"
}

output "Database Name" {
  value = "${var.dbname}"
}

output "Database Hostname" {
  value = "${aws_db_instance.db.address}"
}

output "Database Username" {
  value = "${var.dbuser}"
}

output "Database Password" {
  value = "${random_password.password.result}"
}
