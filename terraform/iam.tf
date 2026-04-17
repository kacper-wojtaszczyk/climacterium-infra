resource "scaleway_iam_application" "pipeline" {
  name        = "jackfruit-pipeline"
  description = "Jackfruit ETL pipeline — S3 read/write access to jackfruit-raw"
}

resource "scaleway_iam_policy" "pipeline_s3" {
  name           = "jackfruit-pipeline-s3"
  application_id = scaleway_iam_application.pipeline.id

  rule {
    permission_set_names = ["ObjectStorageReadOnly", "ObjectStorageObjectsWrite"]
    project_ids          = [var.project_id]
  }
}

resource "scaleway_iam_api_key" "pipeline" {
  application_id = scaleway_iam_application.pipeline.id
  description    = "Jackfruit pipeline S3 access"
}

resource "scaleway_iam_application" "github_actions" {
  name        = "github-actions-deploy"
  description = "Container registry access for deployment pipelines"
}

resource "scaleway_iam_policy" "github_actions_cr" {
  name           = "github-actions-container-registry"
  application_id = scaleway_iam_application.github_actions.id

  rule {
    permission_set_names = ["ContainerRegistryFullAccess"]
    project_ids          = [var.project_id]
  }
}

resource "scaleway_iam_api_key" "github_actions" {
  application_id = scaleway_iam_application.github_actions.id
  description    = "GitHub Actions deployment pipelines"
}
