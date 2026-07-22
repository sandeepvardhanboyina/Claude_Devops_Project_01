# Two groups with a deliberate trust relationship: the internet may reach the
# ALB, and only the ALB may reach the instances. Instances are never addressable
# from the internet on port 80 even though they sit in public subnets.
#
# Rules are declared as separate aws_vpc_security_group_*_rule resources rather
# than inline ingress/egress blocks. Inline blocks are authoritative and silently
# revert any out-of-band change; separate resources also let one group reference
# another without a dependency cycle.

# ---------------------------------------------------------------------------
# ALB security group — public entry point
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "Allows inbound HTTP from the internet to the load balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

# Egress is scoped to the instance group rather than 0.0.0.0/0: the ALB only
# ever needs to reach its targets.
resource "aws_vpc_security_group_egress_rule" "alb_to_instances" {
  security_group_id = aws_security_group.alb.id
  description       = "Forward traffic to instance targets"

  referenced_security_group_id = aws_security_group.instance.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# ---------------------------------------------------------------------------
# Instance security group — reachable only via the ALB, plus admin SSH
# ---------------------------------------------------------------------------

resource "aws_security_group" "instance" {
  name        = "${var.name}-instance-sg"
  description = "Allows HTTP from the load balancer and SSH from the administrator"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-instance-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Referencing the ALB's group id (not a CIDR) means this stays correct however
# the ALB's addresses change, and nothing else in the VPC can reach port 80.
resource "aws_vpc_security_group_ingress_rule" "instance_http_from_alb" {
  security_group_id = aws_security_group.instance.id
  description       = "HTTP from the load balancer only"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# SSH is restricted to a single administrator address. The variable's validation
# rejects 0.0.0.0/0 outright rather than trusting the operator to remember.
resource "aws_vpc_security_group_ingress_rule" "instance_ssh" {
  count = var.allowed_ssh_cidr == null ? 0 : 1

  security_group_id = aws_security_group.instance.id
  description       = "SSH from the administrator address"

  cidr_ipv4   = var.allowed_ssh_cidr
  from_port   = 22
  to_port     = 22
  ip_protocol = "tcp"
}

# Instances need outbound access to install packages, pull the CloudWatch agent
# and reach the SSM and CloudWatch endpoints. Restricting this further would
# require VPC endpoints, which are out of scope here.
resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.instance.id
  description       = "Outbound for package installation and AWS API calls"

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
