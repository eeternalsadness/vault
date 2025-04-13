resource "vault_policy" "policy" {
  for_each = { for file_name in fileset(var.repo-path-policy, "*.hcl") : trimsuffix(file_name, ".hcl") => file(format("%s/%s", var.repo-path-policy, file_name)) }

  name   = each.key
  policy = each.value
}
