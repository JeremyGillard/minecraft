locals {
  project_name         = "Minecraft"
  resource_location    = "West Europe"
  project_name_id      = lower(replace(local.project_name, " ", ""))
  resource_location_id = lower(replace(local.resource_location, " ", ""))
  project_id           = "${local.resource_location_id}-${local.project_name_id}"
}