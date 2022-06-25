locals {
  name                 = "aws-efs-csi-driver"
  service_account_name = "efs-csi-sa"
  namespace            = "kube-system"

  default_helm_config = {
    name        = local.name
    chart       = local.name
    repository  = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
    version     = "2.2.6"
    namespace   = local.namespace
    values      = []
    description = "The AWS EFS CSI driver Helm chart deployment configuration"
  }

  helm_config = merge(
    local.default_helm_config,
    var.helm_config
  )

  set_values = [
    {
      name  = "controller.serviceAccount.name"
      value = local.service_account_name
    },
    {
      name  = "controller.serviceAccount.create"
      value = false
    },
    {
      name  = "node.serviceAccount.name"
      value = local.service_account_name
    },
    {
      name  = "node.serviceAccount.create"
      value = false
    }
  ]

  irsa_config = {
    kubernetes_namespace              = local.namespace
    kubernetes_service_account        = local.service_account_name
    create_kubernetes_namespace       = false
    create_kubernetes_service_account = true
    irsa_iam_policies                 = concat([aws_iam_policy.aws_efs_csi_driver.arn], var.irsa_policies)
    tags                              = var.addon_context.tags
  }
}

#-------------------------------------------------
# EFS CSI Driver Helm Add-on
#-------------------------------------------------
module "helm_addon" {
  source            = "../helm-addon"
  manage_via_gitops = var.manage_via_gitops
  set_values        = local.set_values
  helm_config       = local.helm_config
  irsa_config       = local.irsa_config
  addon_context     = var.addon_context
}

#-------------------------------------------------
# IRSA IAM policy for EFS CSI Driver
#-------------------------------------------------
resource "aws_iam_policy" "aws_efs_csi_driver" {
  name        = "${var.addon_context.eks_cluster_id}-efs-csi-policy"
  description = "IAM Policy for AWS EFS CSI Driver"
  policy      = data.aws_iam_policy_document.aws_efs_csi_driver.json
  tags        = var.addon_context.tags
}

data "aws_iam_policy_document" "aws_efs_csi_driver" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["elasticfilesystem:CreateAccessPoint"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]
    actions   = ["elasticfilesystem:DeleteAccessPoint"]

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/efs.csi.aws.com/cluster"
      values   = ["true"]
    }
  }
}
