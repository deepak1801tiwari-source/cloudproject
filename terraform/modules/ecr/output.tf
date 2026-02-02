output "repository_urls" {
  value = {
    for k, repo in aws_ecr_repository.this :
    k => repo.repository_url
  }
}
