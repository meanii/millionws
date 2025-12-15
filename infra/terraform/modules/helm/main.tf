resource "helm_release" "deployments" {
  for_each         = var.helm_deployments
  name             = each.key
  repository       = each.value.repository
  chart            = each.value.chart
  version          = each.value.version
  namespace        = each.value.namespace
  values           = each.value.values
  create_namespace = each.value.create_namespace
}
