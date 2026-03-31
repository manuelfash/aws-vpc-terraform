resource "aws_vpc" "prod" {
  cidr_block = var.testcidr
}

#hello
#create subnet1

resource "aws_subnet" "subnet1" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true   

  tags = {
    Name = "subnet1"
  }
}

#create subnet2
resource "aws_subnet" "subnet2" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true 

  tags = {
    Name = "subnet2"
  }
}

#build internet gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "igw"
  }
}

#create route table to route subnet traffic
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "route_table"
  }
}

#create route table associations
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.RT.id
}

#create route table associations
resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.RT.id
}

#create web-sg
resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http"
  description = "Allow http & ssh inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.prod.id

  tags = {
    Name = "allow_http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = aws_vpc.prod.cidr_block
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = aws_vpc.prod.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}


resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_http_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}



resource "aws_instance" "webserver1" {
  ami = "ami-0b6c6ebed2801a5cb"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]
  subnet_id = aws_subnet.subnet1.id
  user_data = base64encode(file("userdata.sh"))
}

resource "aws_instance" "webserver2" {
  ami = "ami-0b6c6ebed2801a5cb"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http_ssh.id]
  subnet_id = aws_subnet.subnet2.id
  user_data = base64encode(file("userdata1.sh"))
}

resource "aws_lb" "prodALB" {
  name               = "prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.allow_http_ssh.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "prodTG" {
  name     = "prod-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.prod.id
}

resource "aws_lb_target_group_attachment" "TGA1" {
  target_group_arn = aws_lb_target_group.prodTG.arn
  target_id        = aws_instance.webserver1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "TGA2" {
  target_group_arn = aws_lb_target_group.prodTG.arn
  target_id        = aws_instance.webserver2.id
  port             = 80
}

resource "aws_lb_listener" "listner" {
  load_balancer_arn = aws_lb.prodALB.arn
  port              = "80"
  protocol          = "HTTP"
  

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prodTG.arn
  }
}

output "ALBDNS" {
  value = aws_lb.prodALB.dns_name
}