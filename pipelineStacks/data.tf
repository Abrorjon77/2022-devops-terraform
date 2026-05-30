data "aws_ssm_parameter" "git-token" {
  name = "/github/authorization-token"
}