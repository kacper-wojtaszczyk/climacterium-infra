resource "scaleway_rdb_instance" "postgres" {
  name           = "jackfruit-postgres"
  node_type      = "DB-DEV-S"
  engine         = "PostgreSQL-17"
  is_ha_cluster  = false
  disable_backup = false
  region         = var.region

  private_network {
    pn_id       = scaleway_vpc_private_network.main.id
    enable_ipam = true
  }

  tags = ["jackfruit"]
}

resource "scaleway_rdb_user" "admin" {
  instance_id = scaleway_rdb_instance.postgres.id
  name        = "jackfruit-admin"
  password    = var.postgres_password
  is_admin    = true
  region      = var.region
}

resource "scaleway_rdb_database" "dagster" {
  instance_id = scaleway_rdb_instance.postgres.id
  name        = "dagster"
  region      = var.region
}

resource "scaleway_rdb_privilege" "dagster_admin" {
  instance_id   = scaleway_rdb_instance.postgres.id
  user_name     = scaleway_rdb_user.admin.name
  database_name = scaleway_rdb_database.dagster.name
  permission    = "all"
  region        = var.region
}

resource "scaleway_rdb_database" "jackfruit" {
  instance_id = scaleway_rdb_instance.postgres.id
  name        = "jackfruit"
  region      = var.region
}

resource "scaleway_rdb_privilege" "jackfruit_admin" {
  instance_id   = scaleway_rdb_instance.postgres.id
  user_name     = scaleway_rdb_user.admin.name
  database_name = scaleway_rdb_database.jackfruit.name
  permission    = "all"
  region        = var.region
}