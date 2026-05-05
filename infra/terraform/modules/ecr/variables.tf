variable "name_prefix" {
  type        = string
  description = "Name prefix for repositories."
}

variable "repositories" {
  type        = list(string)
  description = "Repository suffixes."
}
