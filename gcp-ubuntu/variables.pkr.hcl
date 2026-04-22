variable "project_id" {
  type        = string
  description = "The GCP project ID where the image will be built."
}

variable "zone" {
  type        = string
  description = "The GCP zone where the build instance will run."
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "The GCP machine type to use for the build instance."
  default     = "e2-standard-2"
}

variable "image_name" {
  type        = string
  description = "The base name of the resulting Compute Engine image. A timestamp is appended automatically."
  default     = "ubuntu-2404-lts"
}

variable "image_family" {
  type        = string
  description = "The family name assigned to the resulting image."
  default     = "ubuntu-custom"
}

variable "disk_size" {
  type        = number
  description = "The size of the boot disk in GB."
  default     = 20
}
