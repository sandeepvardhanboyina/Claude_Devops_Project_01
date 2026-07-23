# Launch template consumed by the Auto Scaling Group. Every instance the ASG
# creates — at launch, during a scale-out, or when replacing a failed host —
# is built from this definition.

# Resolve the AMI at plan time rather than pinning an ID, which would be both
# region-specific and stale within weeks.
data "aws_ami" "ubuntu" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    enable_cloudwatch_agent = var.enable_cloudwatch_agent
    metrics_namespace       = var.metrics_namespace
    log_group_prefix        = "/aws/ec2/${var.name}"
  })
}

resource "aws_launch_template" "this" {
  name_prefix   = "${var.name}-lt-"
  description   = "Web server template for ${var.name}"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [var.security_group_id]

  iam_instance_profile {
    name = var.instance_profile_name
  }

  user_data = base64encode(local.user_data)

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # IMDSv2 required. With http_tokens set to "optional" an SSRF bug in anything
  # running on the box can read the instance credentials with a plain GET;
  # requiring a token forces a PUT first, which browsers and most SSRF
  # primitives cannot perform.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # Tags on the template do not reach the instances it launches; these blocks
  # are what actually label the running resources.
  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.name}-web"
      Role = "web"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${var.name}-web-volume"
    }
  }

  tags = {
    Name = "${var.name}-launch-template"
  }

  # The ASG holds a reference to this template, so a replacement must exist
  # before the old one is destroyed.
  lifecycle {
    create_before_destroy = true
  }
}
