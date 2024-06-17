#
# Variables for Google resources
#
variable "project_id" {
  description = "The Google Cloud project ID to deploy to"
  type        = string
}
variable "region" {
  description = "The Google Cloud region to deploy to"
  type        = string
  default     = "us-central1"
}
variable "zone" {
  description = "The Google Cloud zone to deploy to"
  type        = string
  default     = "us-central1-a"
}
