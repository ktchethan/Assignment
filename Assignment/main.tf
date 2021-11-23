provider "aws" {
  access_key = “ACCESS_KEY_HERE”
  secret_key = “SECRET_KEY_HERE”
  region = "us-west-2"
}

locals {
  domain_name = "terraform-aws-modules.modules.tf"
}

##################################################################
# Data sources to get VPC and subnets
##################################################################
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "random_pet" "this" {
  length = 2
}

data "aws_route53_zone" "this" {
  name = local.domain_name
}

module "acm" {
  source = "terraform-aws-modules/acm/aws"

  domain_name = local.domain_name 
  zone_id     = data.aws_route53_zone.this.id
}

resource "aws_eip" "this" {
  count = length(data.aws_subnet_ids.all.ids)

  vpc = true
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        =  cidrsubnet(data.aws_vpc.default.cidr_block, 4, 1)
  availability_zone = "us-west-2"

  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_security_group" "prod-web-servers-sg" {
  name        = "prod-web-servers-sg"
  description = "Allow TCP inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress =[ {
    description      = "TCP from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  },
  {
    description      = "TCP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ]

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tcp"
  }
}

resource "aws_instance" "prod-web-server-1" {
  ami           = "ami-0533f2ba8a1995cf9"
  instance_type = "t3.large"
  key_name      = "MyKeyPair1"
  
  vpc_id            = aws_vpc.aws_default_vpc.id
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = aws_security_group.prod-web-servers-sg.id
  


  tags = {
    "Name" : "prod-web-server-1"
  }
}

resource "aws_instance" "prod-web-server-2" {
  ami           = "ami-0533f2ba8a1995cf9"
  instance_type = "t3.large"
  key_name      = "MyKeyPair2"
  
  vpc_id            = aws_vpc.aws_default_vpc.id
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = aws_security_group.prod-web-servers-sg.id
  


  tags = {
    "Name" : "prod-web-server-2"
  }
}

##################################################################
# Network Load Balancer with Elastic IPs attached
##################################################################
module "nlb" {
  source = "../../"

  name = "complete-nlb-${random_pet.this.id}"

  load_balancer_type = "network"

  vpc_id = data.aws_vpc.default.id

  subnet_mapping = [for i, eip in aws_eip.this : { allocation_id : eip.id, subnet_id : tolist(data.aws_subnet_ids.all.ids)[i] }] 
  
  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      targets = [
        {
          target_id = aws_instance.prod-web-server-1.id 
          port = 80
        },
        {
          target_id = aws_instance.prod-web-server-2.id 
          port = 8080
        }
      ]
    }
  ]

  https_listeners = [
    {
      port               = 443
      protocol           = "HTTPS"     
      target_group_index = 0
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 1
    }
  ]

   #  TLS
  https_listeners = [
    {
      port               = 84
      protocol           = "TLS"
      certificate_arn    = module.acm.acm_certificate_arn
      target_group_index = 3
    },
  ]

  tags = {
    Environment = "Test"
  }
  
}