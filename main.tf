terraform {
  required_providers {
    bigip = {
      source  = "f5networks/bigip"
      version = "1.3.2"
    }
  }
}

data "template_file" "as3_init" {
  for_each = local.grouped
  template = file("${path.module}/as3.tmpl")
  vars = {
    tenant_name       = var.tenant_name,
    app_name          = each.key
    vs_server_address = jsonencode(distinct(each.value.*.meta.VSIP))
    pool_name         = format("%s-pool", each.key)
    service_address   = jsonencode(distinct(each.value.*.node_address))
    service_port      = jsonencode(element(distinct(each.value.*.port), 0))
  }
}

resource "bigip_as3" "as3-example-consul" {
  for_each = local.grouped
  as3_json = data.template_file.as3_init[each.key].rendered
}

locals {
  //as3_json = data.template_file.as3_init
  addresses = [
    for id, s in var.services :
    "${s.node_address}"
  ]

  # Create a map of service names to instance IDs
  service_ids = transpose({
    for id, s in var.services : id => [s.name]
    if lookup(s.meta, "VSIP", "") != "" && lookup(s.meta, "VSPORT", "") != ""
  })

  # Group service instances by name
  grouped = { for name, ids in local.service_ids :
    name => [
      for id in ids : var.services[id]
      if lookup(var.services[id].meta, "VSIP", "") != "" && lookup(var.services[id].meta, "VSPORT", "") != ""
    ]
  }
}

// output "service_ids" {
//   value = local.service_ids
// }

// output "service_instances" {
//   value = local.grouped
// }
