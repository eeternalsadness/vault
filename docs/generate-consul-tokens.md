# Generate Consul Tokens

- [Create Consul policies](#create-consul-policies)
- [Configure Consul backend roles](#configure-consul-backend-roles)
- [Use Vault to generate Consul tokens](#use-vault-to-generate-consul-tokens)

You can use Vault to generate short-lived Consul tokens through the Consul secrets backend. This allows you to define the ACL policies in Consul, then configure roles in Vault that contain these policies.

## Create Consul policies

First, you need to create Consul policies that can be used by Vault's Consul backend roles. If the policies that you need already exist, skip ahead to [create the Consul backend roles in Vault](#configure-consul-backend-roles).

Go to the `Policies` tab on the Consul UI and click `Create`. See Consul's documentation on [rules](https://developer.hashicorp.com/consul/docs/secure/acl/rule) and [policies](https://developer.hashicorp.com/consul/docs/secure/acl/policy) for more information on how to write rules in HCL format. The name of the created policy will be used in the Consul backend role configuration.

```hcl
# allow reads & writes on terraform/grafana path
key_prefix "terraform/grafana" {
  policy = "write"
}

# allow session creation
session_prefix "" {
  policy = "write"
}
```

## Configure Consul backend roles

Create a configuration file in `envs/{env}/secrets/consul` to create a new Consul backend role. Make sure to include the names of the necessary Consul policies in the `consulPolicies` field.

```yaml
metadata:
  # name of the Consul secrets engine role
  name: terraform-grafana
spec:
  # list of Consul policies to attach to this role
  consulPolicies:
    - terraform-grafana
  # duration in seconds that the token for the role is valid for
  ttlSeconds: 14400 # 4 hours
```

## Use Vault to generate Consul tokens

Once the Consul backend role has been configured, you can use `vault read` to generate a short-lived Consul token.

```bash
vault read consul/creds/terraform-grafana
```

The token should be included in the command's output. You can export this token as `CONSUL_HTTP_TOKEN` if you need to work with Consul.
