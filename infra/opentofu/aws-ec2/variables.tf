variable "region" {
  description = "One region for everything (cost estimates use us-east-1)."
  type        = string
  default     = "us-east-1"
}

variable "my_ip" {
  description = "Your public IP as CIDR (e.g. 1.2.3.4/32): the only address allowed to SSH and to open Grafana/Prometheus."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "use_spot" {
  description = "Spot by default (~1/3 of on-demand); set false for on-demand."
  type        = bool
  default     = true
}

variable "server_type" {
  description = "Server instance type. Measured need: ~5 GiB RAM for 1M conns, 2 vCPU for margin."
  type        = string
  default     = "m7i-flex.large" # 2 vCPU, 8 GiB: the largest type the AWS free plan may launch; 2 vCPU keeps the fleet inside an 8-vCPU quota
}

variable "client_count" {
  description = "Load generator machines. 3 clients x 16 ports x 64k = ~3M capacity for the 1M target."
  type        = number
  default     = 3
}

variable "client_type" {
  description = "Client instance type. Measured loadgen cost: ~6.6 KiB/conn, so 250k needs ~1.7 GiB plus dialing CPU."
  type        = string
  default     = "c7i-flex.large" # 2 vCPU, 4 GiB: free-plan eligible; holds ~334k conns at ~6.6 KiB each (~2.2 GiB)
}

variable "conns_per_client" {
  description = "Connections each client holds. Total target = client_count x conns_per_client."
  type        = number
  default     = 334000
}

variable "client_replicas" {
  description = "Loadgen containers per client (share the client IP; each spreads over all server ports)."
  type        = number
  default     = 4
}

variable "server_port_first" {
  description = "First server port; server listens on port_first .. port_first + port_count - 1."
  type        = number
  default     = 8080
}

variable "server_port_count" {
  description = "Server ports. One client IP holds ~64k conns per port."
  type        = number
  default     = 16
}

variable "repo_url" {
  description = "Git repository the instances clone and build."
  type        = string
  default     = "https://github.com/meanii/millionws.git"
}

variable "git_ref" {
  description = "Branch, tag or commit SHA to build. Required so every run records exactly what it ran; the default branch (main) does not have the AWS stack or the load generator."
  type        = string
}

variable "max_runtime_minutes" {
  description = "Cost guard: every instance powers off (and terminates) this long after boot, even if tofu destroy is forgotten."
  type        = number
  default     = 240
}

variable "guard_grace_minutes" {
  description = "Extra time the cost watchdog Lambda allows past max_runtime_minutes before it terminates an instance."
  type        = number
  default     = 15
}

variable "server_mem_limit" {
  description = "Memory limit of the server container (docker syntax). The server keeps the Go heap and the 503 admission guard relative to this, so leave room for the OS, Prometheus and Grafana on the same machine: 6g on an 8 GiB instance. 1M connections need about 4.7 GiB at 4.91 KiB each."
  type        = string
  default     = "6g"
}

variable "timezone" {
  description = "System timezone set on every instance, so logs, `date` and cron output line up with the operator's clock. IST by default."
  type        = string
  default     = "Asia/Kolkata"
}

variable "server_maxload" {
  description = "Connection cap of the server (-maxload). It also refuses /metrics requests at the cap, so keep it above what the clients ask for; the default matches the 1M target."
  type        = number
  default     = 1000000
}
