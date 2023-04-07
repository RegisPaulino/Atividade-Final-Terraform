resource "aws_vpc" "ex" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidr_blocks)
  cidr_block        = var.public_subnet_cidr_blocks[count.index]
  vpc_id            = aws_vpc.ex.id
  availability_zone = "us-east-1a" 
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidr_blocks)
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  vpc_id            = aws_vpc.ex.id
  availability_zone = "us-east-1a"  
}

resource "aws_internet_gateway" "ex" {
  vpc_id = aws_vpc.ex.id
}

resource "aws_nat_gateway" "ex" {
  count        = length(var.public_subnet_cidr_blocks)
  subnet_id    = aws_subnet.public[count.index].id
  allocation_id = aws_eip.ex[count.index].id
}

resource "aws_eip" "ex" {
  count = length(var.public_subnet_cidr_blocks)
}

resource "aws_security_group" "web_sg" {
  name_prefix = "web_sg_"

  dynamic "ingress" {
    for_each = ["80", "443"]
    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  vpc_id = var.vpc_id
}

resource "aws_security_group" "db_sg" {
  name_prefix = "db_sg_"

  dynamic "ingress" {
    for_each = aws_security_group.web_sg[*].id
    content {
      from_port = 3306
      to_port   = 3306
      protocol  = "tcp"
      security_groups = [ingress.value]
    }
  }

  vpc_id = var.vpc_id
}

resource "aws_instance" "web_public" {
  count = 5
  ami = "ami-0c77b159cbfafe1f0"
  instance_type = "r2.micro"
  subnet_id = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  tags = {
    Name = "web-public-${count.index}"
    Environment = var.environment
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2"
    ]
  }
}

resource "aws_instance" "web_backend" {
  count = 5
  ami = "ami-0c77b159cbfafe1f0"
  instance_type = "r2.micro"
  subnet_id = aws_subnet.private[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]
  root_block_device {
    volume_size = var.env == "prd" ? 50 : var.env == "hom" ? 30 : 10
    volume_type = "gp3"
  }
  tags = {
    Name = "web-backend-${count.index}"
    Environment = var.environment
  }
  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras install -y nginx1.12",
      "sudo amazon-linux-extras install -y mysql80",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
  }
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-${var.env}-"
  dynamic "ingress" {
    for_each = [80, 3306]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

resource "aws_db_instance" "rds" {
  count       = var.env == "prd" ? 2 : 1
  identifier  = var.env == "prd" ? "rds-mysql-prd-master" : "rds-mysql-${var.env}"
  engine      = "mysql"
  engine_version = "8.0.25"
  instance_class = "db.t3.micro"
  multi_az    = var.env == "prd"
  allocated_storage = var.env == "prd" ? 50 : var.env == "hom" ? 30 : 20
  storage_type = "gp3"
  storage_encrypted = true
  storage_auto_scaling {
    max_capacity = var.env == "prd" ? 100 : null
    min_capacity = var.env == "prd" ? 20 : null
  }
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  subnet_group_name      = aws_db_subnet_group.rds_subnet_group.name

  db_name         = "mydb"
  username        = "myuser"
  password        = "mypassword"
  parameter_group_name = "default.mysql8.0"

  tags = {
    Name = var.env == "prd" ? "rds-mysql-prd-master" : "rds-mysql-${var.env}"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "rds-mysql-${var.env}"
  subnet_ids = [
    aws_subnet.public1.id,
    aws_subnet.public2.id,
    aws_subnet.private1.id,
    aws_subnet.private2.id,
    aws_subnet.private3.id,
  ]
}

resource "aws_db_instance" "rds_replica" {
  count       = var.env == "prd" ? 1 : 0
  identifier  = "rds-mysql-prd-rep"
  engine      = "mysql"
  engine_version = "8.0.25"
  instance_class = "db.t3.micro"
  source_db_instance_identifier = aws_db_instance.rds.id
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  subnet_group_name      = aws_db_subnet_group.rds_subnet_group.name

  tags = {
    Name = "rds-mysql-prd-rep"
  }
}