# Replace with your GCP Project ID
variable "project_id" {
  type    = string
  default = "mrbecker-exam-cdks2"
}

# Replace with your email address
variable "your_email" {
  type    = string
  default = "mrbecker@google.com"
}

# Artifact Registry
resource "google_artifact_registry_repository" "images_repo" {
  project       = var.project_id
  location      = "us-east1"
  repository_id = "images-repo"
  format        = "DOCKER"
  description   = "Exam Docker repository"
}

# Cloud Run Services
resource "google_cloud_run_v2_service" "frontend" {
  name     = "frontend"
  location = "us-east1"
  template {
    containers {
      image = "gcr.io/cloudrun/placeholder"
      ports {
        container_port = 80
      }
    }

  }
  ingress = "INGRESS_TRAFFIC_ALL"
}

resource "google_cloud_run_v2_service" "backend" {
  name     = "backend"
  location = "us-east1"
  template {
    containers {
      image = "gcr.io/cloudrun/placeholder"
    }
  }
  ingress = "INGRESS_TRAFFIC_ALL"
}

# Secret Manager
resource "google_secret_manager_secret" "db_root_password" {
  project = var.project_id
  replication {
    user_managed {
      replicas {
        location = "us-east1"
      }
    }
  }
  secret_id = "db-root-password"
}

resource "random_password" "db_root_password_value" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret_version" "db_root_password_version" {
  secret_data           = random_password.db_root_password_value.result
  is_secret_data_base64 = false
  secret                = google_secret_manager_secret.db_root_password.id
}

resource "google_secret_manager_secret_iam_member" "db_root_password_access" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.db_root_password.secret_id
  member    = "user:${var.your_email}"
  role      = "roles/secretmanager.secretAccessor"
}

# VPC Peering
resource "google_compute_global_address" "managed_vpc_default" {
  project       = var.project_id
  address       = "192.168.0.0"
  name          = "managed-vpc-default"
  prefix_length = 16
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  network       = "projects/${var.project_id}/global/networks/default"
}

resource "google_service_networking_connection" "private_connection" {
  network                 = "projects/${var.project_id}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.managed_vpc_default.name]
  depends_on       = [google_compute_global_address.managed_vpc_default]
}

# Cloud SQL
resource "google_sql_database_instance" "default" {
  project          = var.project_id
  name             = "exam-db"
  region           = "us-east1"
  database_version = "POSTGRES_16"
  depends_on       = [google_service_networking_connection.private_connection]
  settings {
    tier = "db-perf-optimized-N-2"
    ip_configuration {
      ipv4_enabled    = false
      private_network = "projects/${var.project_id}/global/networks/default"
    }
  }
  root_password       = random_password.db_root_password_value.result
  deletion_protection = false
}

# Serverless VPC Access Connector
resource "google_vpc_access_connector" "cloud_run_connector" {
  project       = var.project_id
  name          = "cloud-run-connector"
  region        = "us-east1"
  network       = "default"
  ip_cidr_range = "10.123.0.0/28"
  min_instances = 2
  max_instances = 3
}

# Cloud Run Job - requires private IP of Cloud SQL instance
resource "google_cloud_run_v2_job" "migrate_job" {
  name     = "migrate-job"
  location = "us-east1"
  template {
    template {
      containers {
        image = "gcr.io/cloudrun/placeholder"
        env {
          name  = "DATABASE_URL"
          value = "postgres://postgres:${random_password.db_root_password_value.result}@/postgres?host=${google_sql_database_instance.default.private_ip_address}"
        }
      }
      vpc_access {
        connector = google_vpc_access_connector.cloud_run_connector.id
        egress    = "PRIVATE_RANGES_ONLY"
      }
    }
  }
}
