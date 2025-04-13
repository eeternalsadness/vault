resource "vault_policy" "policy" {
  for_each = { for file_name in fileset(var.path-policy, "*.hcl") : trimsuffix(file_name, ".hcl") => file(format("%s/%s", var.path-policy, file_name)) }

  name   = each.key
  policy = each.value
}
