output "repository_urls" {
  description = "Map of repo name -> repo URL"
  value = {
    for k, repo in aws_ecr_repository.this :
    k => repo.repository_url
  }
}
