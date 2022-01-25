variable "users" {
    type = list(object({
        first_name = string
        last_name = string
        initial_password = string
        username = string
        email = string
    }))
    description = "List of user infos"
}

variable "username" {
    type = string
    description = "(optional) describe your variable"
}

variable "passwd" {
    type = string
    description = "(optional) describe your variable"
}

variable "client_id" {
    type = string
    description = "(optional) describe your variable"
}

variable "vault_url" {
    type = string
    description = "(optional) describe your variable"
}

variable "keycloak_url" {
    type = string
    description = "(optional) describe your variable"
}