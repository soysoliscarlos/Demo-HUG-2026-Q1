package terraform.deny_public_internet

import rego.v1

#
# Rego policy to ensure that no resource in a Terraform plan exposes public
# network access. This policy inspects resource changes in the plan (tfplan/v2)
# and emits a message in the `deny` set for each violation found. It checks
# common public access flags on Azure resources (Storage, Key Vault, AI Services,
# AI Foundry, etc.) and inspects network security group rules to prevent outbound
# access to the Internet.
#

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    after := rc.change.after

    # Check Azure Storage account: block public blob access or public network access
    rc.type == "azurerm_storage_account"

    # allow_blob_public_access exists and is true
    after.allow_blob_public_access == true

    msg := sprintf("Storage account %s has allow_blob_public_access = true", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    after := rc.change.after

    # property may be named public_network_access (string) or public_network_access_enabled (boolean)
    pn_str := lower(after.public_network_access)
    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("Storage account %s has public_network_access = %s", [rc.name, after.public_network_access])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    after := rc.change.after

    # Verificar que public_network_access_enabled sea true (no cumple la política)
    pn_bool := after.public_network_access_enabled
    is_boolean(pn_bool)
    pn_bool == true

    msg := sprintf("Storage account %s has public_network_access_enabled = true (debe ser false)", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_key_vault"
    after := rc.change.after

    # If public network access is not disabled or the flag is true
    pn_str := lower(after.public_network_access)

    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("Key Vault %s has public network access enabled", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_key_vault"
    after := rc.change.after

    # Verificar que public_network_access_enabled sea true (no cumple la política)
    pn_bool := after.public_network_access_enabled
    is_boolean(pn_bool)
    pn_bool == true

    msg := sprintf("Key Vault %s has public_network_access_enabled = true (debe ser false)", [rc.name])
}

# DISABLED: Key Vault network ACLs default_action check
# deny contains msg if {
#     some i
#     rc := input.resource_changes[i]
#     rc.type == "azurerm_key_vault"
#     after := rc.change.after
#
#     # Check network ACLs: default action must be Deny and bypass must be None
#     nacls := get_first(after.network_acls)
#     default_action := lower(nacls.default_action)
#
#     default_action != "deny"
#
#     msg := sprintf("Key Vault %s has network_acls default_action=%s (expected Deny)", [rc.name, nacls.default_action])
# }

# DISABLED: Key Vault network ACLs bypass check
# deny contains msg if {
#     some i
#     rc := input.resource_changes[i]
#     rc.type == "azurerm_key_vault"
#     after := rc.change.after
#
#     # Check network ACLs: default action must be Deny and bypass must be None
#     nacls := get_first(after.network_acls)
#     bypass := lower(nacls.bypass)
#
#     bypass != "none"
#
#     msg := sprintf("Key Vault %s has network_acls bypass=%s (expected None)", [rc.name, nacls.bypass])
# }

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_services"
    after := rc.change.after

    after.public_network_access
    pn_str := lower(after.public_network_access)
    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("AI service %s has public_network_access = %s", [rc.name, after.public_network_access])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_services"
    after := rc.change.after

    pn_bool := after.public_network_access_enabled
    is_boolean(pn_bool)
    pn_bool

    msg := sprintf("AI service %s has public network access enabled", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_foundry"
    after := rc.change.after

    # Verificar que el campo existe y no es null
    after.public_network_access
    pn_str := lower(after.public_network_access)
    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("AI Foundry %s has public_network_access = %s", [rc.name, after.public_network_access])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_foundry"
    after := rc.change.after

    pn_bool := after.public_network_access_enabled
    is_boolean(pn_bool)
    pn_bool

    msg := sprintf("AI Foundry %s has public network access enabled", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_foundry_project"
    after := rc.change.after

    pn_str := lower(after.public_network_access)
    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("AI Foundry project %s has public network access enabled", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_ai_foundry_project"
    after := rc.change.after

    pn_bool := after.public_network_access_enabled
    is_boolean(pn_bool)
    pn_bool

    msg := sprintf("AI Foundry project %s has public network access enabled", [rc.name])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    after := rc.change.after

    # Catch-all for any resource with `public_network_access` string attribute
    # (not limited to specific types). If the attribute exists and is not "Disabled", we flag it.
    # Exclude types that have specific rules to avoid duplicates
    rc.type != "azurerm_storage_account"
    rc.type != "azurerm_key_vault"
    rc.type != "azurerm_ai_services"
    rc.type != "azurerm_ai_foundry"
    rc.type != "azurerm_ai_foundry_project"
    after.public_network_access
    pn_str := lower(after.public_network_access)
    pn_str != ""
    pn_str != "disabled"

    msg := sprintf("Resource %s (%s) has public_network_access = %s", [rc.name, rc.type, after.public_network_access])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    after := rc.change.after

    # Catch-all for any resource with `public_network_access_enabled` boolean true
    # Exclude types that have specific rules to avoid duplicates
    rc.type != "azurerm_storage_account"
    rc.type != "azurerm_key_vault"
    rc.type != "azurerm_ai_services"
    rc.type != "azurerm_ai_foundry"
    rc.type != "azurerm_ai_foundry_project"
    after.public_network_access_enabled == true

    msg := sprintf("Resource %s (%s) has public_network_access_enabled = true", [rc.name, rc.type])
}

deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    after := rc.change.after
    rules := arrayify(after.security_rule)

    # Check for outbound allow rules that target Internet or 0.0.0.0/0
    some j
    rule := rules[j]
    lower(rule.direction) == "outbound"
    lower(rule.access) == "allow"
    dest := get_destination(rule)
    is_open_internet(dest)

    msg := sprintf("Network Security Group %s has an outbound rule '%s' allowing traffic to %s", [rc.name, rule.name, dest])
}

# DISABLED: Network Security Group outbound deny rule check
# deny contains msg if {
#     some i
#     rc := input.resource_changes[i]
#     rc.type == "azurerm_network_security_group"
#     after := rc.change.after
#     rules := arrayify(after.security_rule)
#
#     # Ensure there is at least one outbound rule denying all traffic to Internet (0.0.0.0/0 or Internet)
#     not exists_deny_outbound(rules)
#
#     msg := sprintf("Network Security Group %s does not contain an outbound deny rule to Internet", [rc.name])
# }

###############################################################################
# Helper functions

# Extract the first element of a list or return an empty object
get_first(list) := obj if {
    list != null
    list != []
    obj := list[0]
}

get_first(list) := {} if {
    list == null
}

get_first(list) := {} if {
    list == []
}

# Check if a value is an array (helper function)
is_array(val) if {
    _ := val[_]
}

# Convert value to list; if it is already a list, return as is; else return empty list
arrayify(val) := arr if {
    is_array(val)
    arr := val
}

arrayify(val) := [] if {
    not is_array(val)
}

# Determine destination address prefix for an NSG rule
get_destination(rule) := dest if {
    # Use destination_address_prefixes if available and not empty
    rule.destination_address_prefixes != null
    count(rule.destination_address_prefixes) > 0
    dest := rule.destination_address_prefixes[0]
}

get_destination(rule) := dest if {
    # fallback to single prefix when destination_address_prefixes is null
    rule.destination_address_prefixes == null
    rule.destination_address_prefix != null
    dest := rule.destination_address_prefix
}

get_destination(rule) := dest if {
    # fallback to single prefix when destination_address_prefixes is empty
    rule.destination_address_prefixes != null
    count(rule.destination_address_prefixes) == 0
    rule.destination_address_prefix != null
    dest := rule.destination_address_prefix
}

# Determine if a prefix is considered "Internet"
is_open_internet(prefix) if {
    p := lower(prefix)
    p == "*"
}

is_open_internet(prefix) if {
    p := lower(prefix)
    p == "internet"
}

is_open_internet(prefix) if {
    p := lower(prefix)
    p == "0.0.0.0/0"
}

# Check if there is at least one outbound deny to Internet in a set of rules
exists_deny_outbound(rules) if {
    some k
    rule := rules[k]
    lower(rule.direction) == "outbound"
    lower(rule.access) == "deny"
    dest := get_destination(rule)
    is_open_internet(dest)
}

# Check if a value is boolean
is_boolean(x) if {
    x == true
}

is_boolean(x) if {
    x == false
}

###############################################################################
# Exit-code friendly flag

# This boolean rule is DEFINED only when there are violations.
# Use it with `--fail-defined` so the CLI exits non-zero iff violations exist.
# Example:
#   opa eval --input ../Terraform/plan.json \
#            --data deny_public_internet.rego \
#            --fail-defined "data.terraform.deny_public_internet.violations"

violations if {
    count(deny) > 0
}
