resource "scaleway_object_bucket" "jackfruit_raw" {
  name   = "jackfruit-raw"
  region = var.region

  tags = {
    project = "jackfruit"
  }
}
