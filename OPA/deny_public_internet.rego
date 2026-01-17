# ==============================================================================
# POLÍTICA OPA: DENEGAR ACCESO PÚBLICO A INTERNET
# ==============================================================================
# Esta política valida que ningún recurso en un plan de Terraform tenga acceso
# público a Internet habilitado. Analiza los cambios de recursos en el plan
# (formato tfplan/v2) y emite mensajes en el conjunto `deny` para cada violación.
#
# Recursos validados:
# - Azure Storage Account (blob público y acceso de red público)
# - Azure Key Vault (acceso de red público)
# - Network Security Groups (reglas de salida que permiten tráfico a Internet)
# - Recursos genéricos con flags de acceso público
# ==============================================================================

# Declaración del paquete: define el namespace de la política
# Este namespace se usa para acceder a las reglas desde OPA CLI:
# data.terraform.deny_public_internet.deny
package terraform.deny_public_internet

# Importar la sintaxis moderna de Rego (v1)
# Esto permite usar sintaxis más clara y moderna en las reglas
import rego.v1

# ==============================================================================
# REGLAS DE DENEGACIÓN POR TIPO DE RECURSO
# ==============================================================================
# Cada regla `deny` se evalúa independientemente. Si una regla se cumple,
# se agrega un mensaje al conjunto `deny`. Todas las reglas se evalúan
# para cada recurso en el plan de Terraform.
# ==============================================================================

# ------------------------------------------------------------------------------
# REGLA 1: Azure Storage Account - Blob Public Access
# ------------------------------------------------------------------------------
# Valida que los Storage Accounts no tengan habilitado el acceso público a blobs.
# Esta es una configuración de seguridad crítica que puede exponer datos
# sensibles públicamente.
# ------------------------------------------------------------------------------
deny contains msg if {
    # `some i` declara una variable de iteración que recorre todos los recursos
    # en el plan de Terraform
    some i
    
    # `rc` (resource change) contiene la información del recurso que está siendo
    # evaluado. `input.resource_changes` es un array con todos los cambios
    # propuestos en el plan de Terraform
    rc := input.resource_changes[i]
    
    # `after` contiene el estado del recurso después de aplicar los cambios.
    # En un plan de Terraform, cada recurso tiene `change.before` (estado actual)
    # y `change.after` (estado propuesto)
    after := rc.change.after

    # Filtrar solo recursos de tipo Azure Storage Account
    # El tipo de recurso en Terraform se identifica como "azurerm_storage_account"
    rc.type == "azurerm_storage_account"

    # Verificar si el flag `allow_blob_public_access` está configurado como `true`
    # Si este flag es true, los blobs pueden ser accesibles públicamente sin
    # autenticación, lo cual es un riesgo de seguridad
    after.allow_blob_public_access == true

    # Si todas las condiciones anteriores se cumplen, generar un mensaje de
    # violación. El mensaje incluye el nombre del recurso para facilitar
    # la identificación del problema
    msg := sprintf("Storage account %s has allow_blob_public_access = true", [rc.name])
}

# ------------------------------------------------------------------------------
# REGLA 2: Azure Storage Account - Public Network Access (String)
# ------------------------------------------------------------------------------
# Valida que los Storage Accounts no tengan acceso de red público habilitado
# cuando se usa la propiedad como string. Azure puede usar diferentes formatos:
# - String: "Enabled" / "Disabled"
# - Boolean: true / false
# Esta regla maneja el caso de string.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    
    # Filtrar solo Storage Accounts
    rc.type == "azurerm_storage_account"
    
    # Obtener el estado después del cambio
    after := rc.change.after

    # Convertir el valor de `public_network_access` a minúsculas para hacer
    # una comparación case-insensitive. Esto maneja variaciones como
    # "Enabled", "ENABLED", "enabled", etc.
    pn_str := lower(after.public_network_access)
    
    # Verificar que el campo existe (no es null) y no está vacío
    # Si el campo no existe, no se considera una violación (asumimos que
    # el valor por defecto es seguro)
    pn_str != ""
    
    # Verificar que el valor NO sea "disabled" (case-insensitive)
    # Si el valor es "disabled" o está vacío, la configuración es segura
    pn_str != "disabled"

    # Si el valor existe y no es "disabled", generar mensaje de violación
    # Incluimos el valor actual para que el usuario sepa qué cambiar
    msg := sprintf("Storage account %s has public_network_access = %s", [rc.name, after.public_network_access])
}

# ------------------------------------------------------------------------------
# REGLA 3: Azure Storage Account - Public Network Access (Boolean)
# ------------------------------------------------------------------------------
# Valida que los Storage Accounts no tengan acceso de red público habilitado
# cuando se usa la propiedad como boolean. Esta es la forma más común en
# versiones recientes del provider de Azure para Terraform.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    after := rc.change.after

    # Obtener el valor de `public_network_access_enabled`
    # Este campo puede ser boolean (true/false) o puede no existir
    pn_bool := after.public_network_access_enabled
    
    # Verificar que el valor es realmente un boolean (no null, no string, etc.)
    # Esto evita falsos positivos si el campo tiene un valor inesperado
    is_boolean(pn_bool)
    
    # Verificar que el valor es `true` (acceso público habilitado)
    # Si es `false` o no existe, la configuración es segura
    pn_bool == true

    # Generar mensaje de violación con instrucción clara de qué debe ser el valor
    msg := sprintf("Storage account %s has public_network_access_enabled = true (debe ser false)", [rc.name])
}

# ------------------------------------------------------------------------------
# REGLA 4: Azure Key Vault - Public Network Access (String)
# ------------------------------------------------------------------------------
# Valida que los Key Vaults no tengan acceso de red público habilitado.
# Los Key Vaults contienen secretos y credenciales, por lo que el acceso
# público es un riesgo de seguridad crítico.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    
    # Filtrar solo recursos de tipo Key Vault
    rc.type == "azurerm_key_vault"
    after := rc.change.after

    # Convertir a minúsculas para comparación case-insensitive
    # Maneja variaciones como "Enabled", "ENABLED", "enabled"
    pn_str := lower(after.public_network_access)

    # Verificar que el campo existe y no está vacío
    pn_str != ""
    
    # Verificar que el valor NO es "disabled"
    # Si es "disabled" o no existe, la configuración es segura
    pn_str != "disabled"

    # Generar mensaje de violación
    msg := sprintf("Key Vault %s has public network access enabled", [rc.name])
}

# ------------------------------------------------------------------------------
# REGLA 5: Azure Key Vault - Public Network Access (Boolean)
# ------------------------------------------------------------------------------
# Valida que los Key Vaults no tengan acceso de red público habilitado
# cuando se usa la propiedad como boolean.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_key_vault"
    after := rc.change.after

    # Obtener el valor boolean del flag
    pn_bool := after.public_network_access_enabled
    
    # Verificar que es realmente un boolean (no null u otro tipo)
    is_boolean(pn_bool)
    
    # Verificar que el valor es `true` (acceso público habilitado)
    pn_bool == true

    # Generar mensaje con instrucción clara
    msg := sprintf("Key Vault %s has public_network_access_enabled = true (debe ser false)", [rc.name])
}

# ------------------------------------------------------------------------------
# REGLA 6: Catch-all para Recursos Genéricos - Public Network Access (String)
# ------------------------------------------------------------------------------
# Esta regla captura cualquier recurso que tenga la propiedad `public_network_access`
# como string y no esté deshabilitado. Es una regla genérica que cubre recursos
# que no tienen reglas específicas definidas arriba.
#
# IMPORTANTE: Excluimos tipos de recursos que ya tienen reglas específicas para
# evitar mensajes duplicados. Si un recurso tiene una regla específica, esa regla
# se encarga de generar el mensaje con más contexto.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    after := rc.change.after

    # Excluir tipos de recursos que ya tienen reglas específicas
    # Esto evita generar mensajes duplicados para el mismo recurso
    rc.type != "azurerm_storage_account"
    rc.type != "azurerm_key_vault"
    rc.type != "azurerm_ai_services"
    rc.type != "azurerm_ai_foundry"
    rc.type != "azurerm_ai_foundry_project"
    
    # Verificar que el campo `public_network_access` existe
    # Si no existe, no se considera violación
    after.public_network_access
    
    # Convertir a minúsculas para comparación case-insensitive
    pn_str := lower(after.public_network_access)
    
    # Verificar que el campo no está vacío
    pn_str != ""
    
    # Verificar que el valor NO es "disabled"
    pn_str != "disabled"

    # Generar mensaje genérico que incluye el tipo de recurso
    # Esto ayuda a identificar qué tipo de recurso tiene el problema
    msg := sprintf("Resource %s (%s) has public_network_access = %s", [rc.name, rc.type, after.public_network_access])
}

# ------------------------------------------------------------------------------
# REGLA 7: Catch-all para Recursos Genéricos - Public Network Access (Boolean)
# ------------------------------------------------------------------------------
# Similar a la regla anterior, pero para la propiedad boolean
# `public_network_access_enabled`. Captura cualquier recurso que tenga esta
# propiedad configurada como `true`.
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    after := rc.change.after

    # Excluir tipos de recursos con reglas específicas
    rc.type != "azurerm_storage_account"
    rc.type != "azurerm_key_vault"
    rc.type != "azurerm_ai_services"
    rc.type != "azurerm_ai_foundry"
    rc.type != "azurerm_ai_foundry_project"
    
    # Verificar que `public_network_access_enabled` está configurado como `true`
    # Si es `false` o no existe, no hay violación
    after.public_network_access_enabled == true

    # Generar mensaje genérico
    msg := sprintf("Resource %s (%s) has public_network_access_enabled = true", [rc.name, rc.type])
}

# ------------------------------------------------------------------------------
# REGLA 8: Network Security Group - Reglas de Salida a Internet
# ------------------------------------------------------------------------------
# Valida que los Network Security Groups (NSG) no tengan reglas de salida
# (outbound) que permitan tráfico a Internet abierto. Esto previene que
# recursos dentro de la red puedan comunicarse libremente con Internet,
# lo cual puede ser un riesgo de seguridad.
#
# Esta regla verifica:
# - Reglas con dirección "outbound" (salida)
# - Reglas con acceso "allow" (permitir)
# - Destinos que representan Internet abierto (*, Internet, 0.0.0.0/0)
# ------------------------------------------------------------------------------
deny contains msg if {
    some i
    rc := input.resource_changes[i]
    
    # Filtrar solo recursos de tipo Network Security Group
    rc.type == "azurerm_network_security_group"
    after := rc.change.after
    
    # Convertir `security_rule` a un array si no lo es ya
    # Esto maneja casos donde el campo puede ser null, un array, o no existir
    # La función `arrayify` se define más abajo en las funciones helper
    rules := arrayify(after.security_rule)

    # Iterar sobre todas las reglas de seguridad del NSG
    # `some j` declara una variable de iteración para recorrer las reglas
    some j
    rule := rules[j]
    
    # Verificar que la regla es de dirección "outbound" (salida)
    # Convertimos a minúsculas para comparación case-insensitive
    lower(rule.direction) == "outbound"
    
    # Verificar que la regla tiene acceso "allow" (permitir tráfico)
    # Si es "deny", no hay problema de seguridad
    lower(rule.access) == "allow"
    
    # Obtener el destino de la regla usando la función helper
    # Esta función maneja diferentes formatos de destino (array o string)
    dest := get_destination(rule)
    
    # Verificar si el destino representa Internet abierto
    # Esta función verifica si el destino es "*", "Internet", o "0.0.0.0/0"
    is_open_internet(dest)

    # Generar mensaje de violación que incluye:
    # - Nombre del NSG
    # - Nombre de la regla problemática
    # - Destino que está permitiendo
    msg := sprintf("Network Security Group %s has an outbound rule '%s' allowing traffic to %s", [rc.name, rule.name, dest])
}

# ==============================================================================
# FUNCIONES HELPER
# ==============================================================================
# Estas funciones auxiliares simplifican la lógica de las reglas y permiten
# reutilizar código común. Facilitan el mantenimiento y hacen el código más
# legible.
# ==============================================================================

# ------------------------------------------------------------------------------
# FUNCIÓN: get_first(list)
# ------------------------------------------------------------------------------
# Extrae el primer elemento de una lista o retorna un objeto vacío si la lista
# es null o vacía. Útil para acceder a elementos de arrays que pueden estar
# vacíos o ser null.
#
# Ejemplo de uso: Acceder al primer elemento de network_acls en Key Vault
# ------------------------------------------------------------------------------
# Caso 1: La lista existe y tiene elementos
get_first(list) := obj if {
    # Verificar que la lista no es null
    list != null
    # Verificar que la lista no está vacía
    list != []
    # Retornar el primer elemento (índice 0)
    obj := list[0]
}

# Caso 2: La lista es null
get_first(list) := {} if {
    list == null
}

# Caso 3: La lista está vacía
get_first(list) := {} if {
    list == []
}

# ------------------------------------------------------------------------------
# FUNCIÓN: is_array(val)
# ------------------------------------------------------------------------------
# Verifica si un valor es un array usando pattern matching de Rego.
# En Rego, podemos verificar si un valor es un array intentando acceder
# a un índice arbitrario. Si el acceso es válido, es un array.
#
# Ejemplo: is_array([1, 2, 3]) retorna true
#          is_array("string") retorna false
# ------------------------------------------------------------------------------
is_array(val) if {
    # Intentar acceder a un índice arbitrario del valor
    # Si `val` es un array, esta expresión será verdadera
    # Si `val` no es un array, esta expresión fallará
    _ := val[_]
}

# ------------------------------------------------------------------------------
# FUNCIÓN: arrayify(val)
# ------------------------------------------------------------------------------
# Convierte un valor a lista. Si ya es una lista, la retorna tal cual.
# Si no es una lista (null, objeto, string, etc.), retorna una lista vacía.
#
# Útil para normalizar valores que pueden ser arrays o null, permitiendo
# iterar sobre ellos de forma segura sin errores.
#
# Ejemplo: arrayify([1, 2]) retorna [1, 2]
#          arrayify(null) retorna []
#          arrayify("string") retorna []
# ------------------------------------------------------------------------------
# Caso 1: El valor ya es un array
arrayify(val) := arr if {
    # Verificar que es un array usando la función helper
    is_array(val)
    # Retornar el array tal cual
    arr := val
}

# Caso 2: El valor NO es un array
arrayify(val) := [] if {
    # Si no es un array, retornar lista vacía
    not is_array(val)
}

# ------------------------------------------------------------------------------
# FUNCIÓN: get_destination(rule)
# ------------------------------------------------------------------------------
# Determina el prefijo de dirección de destino para una regla de NSG.
# Las reglas de NSG pueden tener el destino en dos formatos:
# 1. `destination_address_prefixes` (array de prefijos)
# 2. `destination_address_prefix` (string con un solo prefijo)
#
# Esta función prioriza el array si existe y tiene elementos, y hace
# fallback al string si el array está vacío o es null.
#
# Ejemplo: Si rule tiene destination_address_prefixes = ["0.0.0.0/0", "10.0.0.0/8"],
#          retorna "0.0.0.0/0" (primer elemento)
#          Si solo tiene destination_address_prefix = "Internet",
#          retorna "Internet"
# ------------------------------------------------------------------------------
# Caso 1: El array existe y tiene elementos (prioridad)
get_destination(rule) := dest if {
    # Verificar que destination_address_prefixes existe y no es null
    rule.destination_address_prefixes != null
    # Verificar que el array tiene al menos un elemento
    count(rule.destination_address_prefixes) > 0
    # Retornar el primer elemento del array
    dest := rule.destination_address_prefixes[0]
}

# Caso 2: El array es null, usar el string como fallback
get_destination(rule) := dest if {
    # Verificar que el array es null
    rule.destination_address_prefixes == null
    # Verificar que el string existe y no es null
    rule.destination_address_prefix != null
    # Retornar el string
    dest := rule.destination_address_prefix
}

# Caso 3: El array existe pero está vacío, usar el string como fallback
get_destination(rule) := dest if {
    # Verificar que el array existe pero está vacío
    rule.destination_address_prefixes != null
    count(rule.destination_address_prefixes) == 0
    # Verificar que el string existe y no es null
    rule.destination_address_prefix != null
    # Retornar el string
    dest := rule.destination_address_prefix
}

# ------------------------------------------------------------------------------
# FUNCIÓN: is_open_internet(prefix)
# ------------------------------------------------------------------------------
# Verifica si un prefijo de dirección representa acceso abierto a Internet.
# Considera válidos los siguientes valores (case-insensitive):
# - "*" (cualquier destino)
# - "internet" (tag de Azure que representa Internet)
# - "0.0.0.0/0" (notación CIDR que representa toda la red IPv4)
#
# Esta función usa `lower()` para normalizar la comparación y hacerla
# case-insensitive, manejando variaciones como "Internet", "INTERNET", etc.
# ------------------------------------------------------------------------------
# Caso 1: El prefijo es "*" (wildcard - cualquier destino)
is_open_internet(prefix) if {
    # Convertir a minúsculas para comparación case-insensitive
    p := lower(prefix)
    # Verificar si es el wildcard
    p == "*"
}

# Caso 2: El prefijo es "internet" (tag de Azure)
is_open_internet(prefix) if {
    p := lower(prefix)
    # Verificar si es el tag de Internet de Azure
    p == "internet"
}

# Caso 3: El prefijo es "0.0.0.0/0" (toda la red IPv4)
is_open_internet(prefix) if {
    p := lower(prefix)
    # Verificar si es la notación CIDR para toda la red
    p == "0.0.0.0/0"
}

# ------------------------------------------------------------------------------
# FUNCIÓN: exists_deny_outbound(rules)
# ------------------------------------------------------------------------------
# Verifica si existe al menos una regla de salida que deniega tráfico a Internet.
# Esta función está disponible para futuras validaciones, pero actualmente
# no se usa en las reglas activas.
#
# Podría usarse para validar que existe una regla de denegación explícita
# además de verificar que no hay reglas de permitir.
# ------------------------------------------------------------------------------
exists_deny_outbound(rules) if {
    # Iterar sobre todas las reglas
    some k
    rule := rules[k]
    
    # Verificar que la regla es de dirección "outbound"
    lower(rule.direction) == "outbound"
    
    # Verificar que la regla tiene acceso "deny" (denegar)
    lower(rule.access) == "deny"
    
    # Obtener el destino de la regla
    dest := get_destination(rule)
    
    # Verificar si el destino es Internet abierto
    is_open_internet(dest)
}

# ------------------------------------------------------------------------------
# FUNCIÓN: is_boolean(x)
# ------------------------------------------------------------------------------
# Verifica si un valor es de tipo booleano.
# Retorna true si el valor es `true` o `false`.
# Retorna false (o no se define) si el valor es null, string, number, etc.
#
# Esta función es útil para validar tipos antes de hacer comparaciones,
# evitando falsos positivos cuando un campo puede tener diferentes tipos.
#
# Ejemplo: is_boolean(true) retorna true
#          is_boolean(false) retorna true
#          is_boolean(null) no se define (retorna false implícitamente)
#          is_boolean("true") no se define (retorna false implícitamente)
# ------------------------------------------------------------------------------
# Caso 1: El valor es `true`
is_boolean(x) if {
    x == true
}

# Caso 2: El valor es `false`
is_boolean(x) if {
    x == false
}

# ==============================================================================
# REGLA DE VIOLACIONES (Para CI/CD)
# ==============================================================================
# Esta regla booleana se define SOLO cuando hay violaciones (cuando el conjunto
# `deny` tiene elementos). Es útil para usar con `--fail-defined` en OPA CLI,
# lo que hace que el comando salga con código de error no-cero si existen
# violaciones.
#
# Uso en CI/CD:
#   opa eval --input ../Terraform/tfplan.json \
#            --data deny_public_internet.rego \
#            --fail-defined "data.terraform.deny_public_internet.violations"
#
# Si hay violaciones, `violations` se define y el comando falla.
# Si no hay violaciones, `violations` no se define y el comando tiene éxito.
# ==============================================================================
violations if {
    # Contar cuántos elementos hay en el conjunto `deny`
    # Si hay al menos uno, se define la regla `violations`
    count(deny) > 0
}
