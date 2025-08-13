locals {
  # Helper locals for paths and file operations
  kv_secrets_path = "${path.module}/${var.repo-path-secret-kv}"

  # File discovery
  kv_secret_files = fileset(local.kv_secrets_path, "**/*.yaml")

  # Parse YAML configurations
  kv_configs = {
    for file_name in local.kv_secret_files :
    yamldecode(file("${local.kv_secrets_path}/${file_name}")).metadata.path
    => yamldecode(file("${local.kv_secrets_path}/${file_name}"))
  }

  # Helper functions for config properties
  has_timestamp = { for k, v in local.kv_configs : k => contains(keys(v.metadata), "timestamp") }
  has_rotation  = { for k, v in local.kv_configs : k => contains(keys(v.spec), "rotateInterval") }
  has_generated = { for k, v in local.kv_configs : k => contains(keys(v.spec), "generated") }
  has_public    = { for k, v in local.kv_configs : k => contains(keys(v.spec), "public") }
  has_private   = { for k, v in local.kv_configs : k => contains(keys(v.spec), "private") }
  has_import    = { for k, v in local.kv_configs : k => contains(keys(v.spec), "import") }

  # Parse import configurations
  kv_imports = [
    for k, v in local.kv_configs : k
    if local.has_import[k] && local.has_import[k] ? v.spec.import : false
  ]

  # Secrets that need data fetching (have timestamps or are imported)
  secrets_needing_data = concat(
    [for k, v in local.kv_configs : k if local.has_timestamp[k]],
    local.kv_imports
  )

  # Rotation logic - secrets that need rotation based on timestamp + interval
  secrets_for_rotation = {
    for k, v in local.kv_configs :
    k => v
    if local.has_rotation[k] && timecmp(
      timeadd(
        local.has_timestamp[k] ? v.metadata.timestamp : "2001-09-11T00:00:00+00:00",
        try(v.spec.rotateInterval, "0s")
      ),
      plantimestamp()
    ) <= 0
  }

  # Public secrets (fixed key-value pairs)
  public_secrets = {
    for k, v in local.kv_configs : k => v.spec.public
    if local.has_public[k]
  }

  # Private secrets 
  private_secrets = {
    for k, v in local.kv_configs : k =>
    {
      # if there's a timestamp or if it's imported, fetch secret values from vault, otherwise generate stubs
      for private_secret in v.spec.private :
      private_secret =>
      local.has_timestamp[k] || local.has_import[k] ?
      jsondecode(data.vault_kv_secret_v2.kvv2[k].data_json)[private_secret] :
      "-"
    }
    if local.has_private[k]
  }

  # Generated secret keys that need creation
  # Only for secrets that are new (no timestamp) or need rotation
  generated_secret_keys = merge([
    for k, v in local.kv_configs : {
      for secret_key in v.spec.generated : "${k}/${secret_key}" => secret_key
    }
    if local.has_generated[k] && (
      contains(keys(local.secrets_for_rotation), k) || !local.has_timestamp[k]
    )
  ]...)

  # Generated secrets with their values
  generated_secrets = {
    for k, v in local.kv_configs : k => merge([
      {
        for secret_key in v.spec.generated :
        secret_key => data.external.generate-secret-kvv2["${k}/${secret_key}"].result.secret
      }
    ]...)
    if local.has_generated[k] && (
      contains(keys(local.secrets_for_rotation), k) || !local.has_timestamp[k]
    )
  }

  # Combined secrets (public + generated)
  combined_secrets = {
    for key in keys(local.kv_configs) : key => merge(
      try(local.public_secrets[key], {}),
      try(local.generated_secrets[key], {}),
      try(local.private_secrets[key], {})
    )
    if local.has_public[key] || local.has_private[key] || contains(keys(local.generated_secrets), key)
  }
}

# KV v2 Mount
resource "vault_mount" "kvv2" {
  path        = var.vault-path-secret-kv-v2
  type        = "kv"
  description = "KV version 2 secret engine mount"

  options = {
    version = "2"
  }

  seal_wrap                 = true
  default_lease_ttl_seconds = var.kvv2-lease-ttl-seconds
  max_lease_ttl_seconds     = var.kvv2-lease-ttl-seconds

  depends_on = [vault_policy.policy]
}

# KV v2 Backend Configuration
resource "vault_kv_secret_backend_v2" "kvv2" {
  mount                = vault_mount.kvv2.path
  max_versions         = var.kvv2-max-versions
  delete_version_after = var.kvv2-delete-version-after-seconds

  depends_on = [vault_policy.policy]
}

# Data source for existing secrets (imports and timestamped secrets)
data "vault_kv_secret_v2" "kvv2" {
  for_each = toset(local.secrets_needing_data)

  mount = vault_mount.kvv2.path
  name  = each.key
}

# Generate secrets for rotation/new secrets
data "external" "generate-secret-kvv2" {
  for_each = local.generated_secret_keys

  program = ["python3", "scripts/generate-secret.py"]
  query = {
    length  = var.kv-generated-secret-length
    symbols = var.kv-generated-secret-use-symbols
  }
}

# KV Secrets
resource "vault_kv_secret_v2" "kvv2" {
  for_each = local.kv_configs

  mount = vault_mount.kvv2.path
  name  = each.key

  # Use existing data for imports and secrets not needing rotation, otherwise use generated
  data_json = contains(local.secrets_needing_data, each.key) && !contains(keys(local.secrets_for_rotation), each.key) ? data.vault_kv_secret_v2.kvv2[each.key].data_json : try(jsonencode(local.combined_secrets[each.key]), "{}")

  # WARN: delete all versions of secret if the config is deleted
  delete_all_versions = true

  custom_metadata {
    max_versions         = try(local.kv_configs[each.key].spec.maxVersions, null)
    delete_version_after = try(local.kv_configs[each.key].spec.deleteVersionAfterSeconds, null)
  }

  depends_on = [vault_policy.policy]
}

# Update timestamps after secret creation/update
resource "null_resource" "kvv2_update_timestamp" {
  for_each = {
    for file_name in local.kv_secret_files :
    file_name => yamldecode(file("${local.kv_secrets_path}/${file_name}"))
  }

  provisioner "local-exec" {
    command = "python3 scripts/update-timestamp.py $file_path $timestamp"
    environment = {
      file_path = format("%s/%s", local.kv_secrets_path, each.key)
      timestamp = vault_kv_secret_v2.kvv2[each.value.metadata.path].metadata.created_time
    }
  }

  triggers = {
    secret_updated = vault_kv_secret_v2.kvv2[each.value.metadata.path].data_json
  }

  depends_on = [vault_kv_secret_v2.kvv2]
}

# Output secrets that need to be rotated (both automatically and manually)
output "kvv2_secrets_for_rotation" {
  description = "Secrets that need to be rotated (both automatically and manually)"
  value       = keys(local.secrets_for_rotation)
}

# Import existing secrets
import {
  for_each = local.kv_imports

  id = "${vault_mount.kvv2.path}/data/${each.value}"
  to = vault_kv_secret_v2.kvv2[each.value]
}
