variable "helm_deployments" {
  type = map(object({
    enabled          = bool
    name             = string
    repository       = string
    chart            = string
    namespace        = string
    create_namespace = bool
    version          = string
    values           = list(string)
  }))
}
