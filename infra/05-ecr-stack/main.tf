locals {
  prefix = "${var.project}-${var.environment}"
  repos  = toset(var.repositories)

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last ${var.lifecycle_keep_last} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.lifecycle_keep_last
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_repository" "this" {
  for_each             = local.repos
  name                 = "${local.prefix}-${each.value}"
  image_tag_mutability = var.tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy     = local.lifecycle_policy
}