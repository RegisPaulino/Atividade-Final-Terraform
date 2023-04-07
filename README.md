# Atividade-Final-Terraform


Crie 3 Workspaces: - Dev - Hom - Prd

Os recursos deverão respeitar o workspace a ser criado, cada workspace terá seu próprio state;

Os recursos tem que ter no nome uma identificação de ambiente, exemplo: rds-mysql-dev rds-mysql-hom rds-mysql-prd

Crie 1 Bucket S3 com o parecido com: terraform-state-files

Criar um módulo terraform que crie de forma dinâmica: Network: 1 VPC; 3 Subnets Privadas; 3 Subnets Publicas; 1 Nat Gateway; <- Opcional 1 Internet Gateway;

Security groups (Utilizar Dynamic Block):
	1 SG para maquinas Web com as portas 80 e 443 abertas;
	1 SG para bancos de dados abrindo a porta 3306 para o SG Web;

Virtual Machines:
	5 Maquinas Virtuais - Web Publica: 
		Ubuntu 22.04
		Storage gp3 - 20GB
		SG Web
		Subnet Publica
		Com os seguintes pacotes instalados:
			httpd
	5 Maquinas Virtuais - Web Backend: 
		Amazon Linux
		Storage gp3 
			Dev - 10GB
			Hom - 20GB
			Prd - 50GB
		SG Web
		Subnet Privada
		Com os seguintes pacotes instalados:
			nginx
			mysql-client
Banco de Dados:
	1 Instancia de Banco de Dados RDS MySQL
		Versão 8
		Multi-AZ (Apenas em caso de ambiente produtivo)
		Storage gp3 
			Dev - 20GB
			Hom - 30GB
			Prd - 50GB
		Storage Autoscaling (Apenas em caso de ambiente produtivo)
		SG Banco de Dados

	1 Instancia de Replica de Leitura (Apenas para ambiente Produtivo) <- Opcional
Subir no Github e passar endereço para: william.loliveira@hotmail.com

Exemplo:

terraform { required_providers { aws = { source = "hashicorp/aws" version = ">= 3.59.0" } } }

provider "aws" { region = "us-east-1" }

variable "env" { default = "dev" }

data "aws_vpc" "vpc" { id = "vpc-01dc9533c25c6d072" }

data "aws_subnet" "subnet" { id = "subnet-03dd758634314f16f" }

locals { ingress = [{ port = 443 description = "Port 443" protocol = "tcp" }, { port = 80 description = "Port 80" protocol = "tcp" }] tags = { Name = "MyServer-${terraform.workspace}" Env = terraform.workspace }

}

resource "aws_security_group" "sg" { name = "sgweb${terraform.workspace}" description = "Allow TLS inbound traffic" vpc_id = data.aws_vpc.vpc.id

dynamic "ingress" { for_each = local.ingress content { description = ingress.value.description from_port = ingress.value.port to_port = ingress.value.port protocol = ingress.value.protocol cidr_blocks = ["0.0.0.0/0"] ipv6_cidr_blocks = [] prefix_list_ids = [] security_groups = [] self = false } }

egress = [ { description = "outgoing for everyone" from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] ipv6_cidr_blocks = [] prefix_list_ids = [] security_groups = [] self = false } ] }

resource "aws_instance" "servidor" { depends_on = [ aws_security_group.sg ]

ami = "ami-087c17d1fe0178315" instance_type = "t2.micro" subnet_id = data.aws_subnet.subnet.id vpc_security_group_ids = [aws_security_group.sg.id]

tags = merge(local.tags) }
