resource "scaleway_object_bucket" "jackfruit_raw" {
  name   = "jackfruit-raw"
  region = var.region

  tags = {
    project = "jackfruit"
  }
}

resource "scaleway_iam_application" "pipeline" {
  name        = "jackfruit-pipeline"
  description = "Jackfruit ETL pipeline — S3 read/write access to jackfruit-raw"
}

resource "scaleway_iam_policy" "pipeline_s3" {
  name           = "jackfruit-pipeline-s3"
  application_id = scaleway_iam_application.pipeline.id

  rule {
    permission_set_names = ["ObjectStorageFullAccess"]
    project_ids          = [var.project_id]
  }
}

resource "scaleway_iam_api_key" "pipeline" {
  application_id = scaleway_iam_application.pipeline.id
  description    = "Jackfruit pipeline S3 access"
}
