resource "vault_policy" "policy" {
  for_each = {
    for file_name in fileset(format("%s/%s", path.module, var.repo-path-policy), "**/*.hcl") :
    trimsuffix(basename(file_name), ".hcl") => file(format("%s/%s/%s", path.module, var.repo-path-policy, file_name))
  }

  name   = each.key
  policy = each.value
}
