# Instance role. Carries only what the instance genuinely needs:
#
#   CloudWatchAgentServerPolicy   publish memory and disk metrics, which are not
#                                 collected by the hypervisor and so require an agent
#   AmazonSSMManagedInstanceCore  Session Manager access, so an operator can reach a
#                                 shell without SSH or a key pair
#
# Notably absent: any S3, ECR or EC2 write permission, and any wildcard resource.
# An instance serving static files has no reason to call the AWS API beyond this.

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-instance-role"
  description        = "Role assumed by web instances in the ${var.name} Auto Scaling Group"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${var.name}-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance.name

  tags = {
    Name = "${var.name}-instance-profile"
  }
}

# ---------------------------------------------------------------------------
# GitHub Actions deployment role (OIDC)
# ---------------------------------------------------------------------------
# GitHub exchanges a short-lived OIDC token for AWS credentials, so the repo
# needs no long-lived access key. The trust policy pins both the repository and
# the branch, so a fork or an unrelated repo presenting a valid GitHub token
# still cannot assume this role.

data "aws_iam_policy_document" "github_assume_role" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    sid     = "GitHubActionsAssumeRoleWithWebIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for ref in var.github_allowed_refs : "repo:${var.github_repository}:${ref}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  count = var.enable_github_oidc ? 1 : 0

  name               = "${var.name}-github-actions-role"
  description        = "Assumed by GitHub Actions in ${var.github_repository} to plan and apply infrastructure"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role[0].json

  tags = {
    Name = "${var.name}-github-actions-role"
  }
}

# Read-only describe permissions needed to run `terraform plan` and to look up
# instance addresses at deploy time. Apply permissions are intentionally not
# granted here — infrastructure changes are applied from a workstation, so a
# compromised workflow cannot rewrite the network.
data "aws_iam_policy_document" "github_deploy" {
  count = var.enable_github_oidc ? 1 : 0

  statement {
    sid    = "ReadInfrastructureForPlanAndDeploy"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "cloudwatch:Describe*",
      "cloudwatch:GetMetric*",
      "iam:GetRole",
      "iam:GetInstanceProfile",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadTerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]
  }

  # Terraform takes the state lock even for a read-only plan.
  statement {
    sid    = "LockTerraformState"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [var.state_lock_table_arn]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  count = var.enable_github_oidc ? 1 : 0

  name   = "${var.name}-github-actions-policy"
  role   = aws_iam_role.github_actions[0].id
  policy = data.aws_iam_policy_document.github_deploy[0].json
}
