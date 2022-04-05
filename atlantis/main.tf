locals {
  ngrok_endpoint    = "${local.ngrok_name}:${local.ngrok_port}"
  atlantis_endpoint = "${local.atlantis_name}:${local.atlantis_port}"
}

resource "docker_network" "atlantis" {
  name = "atlantis"
}

resource "docker_container" "ngrok" {
  image    = "wernight/ngrok:latest"
  name     = var.ngrok_name
  hostname = var.ngrok_name
  ports {
    internal = var.ngrok_port
    external = var.ngrok_port
  }
  env = [
    "NGROK_PROTOCOL=http",
    "NGROK_PORT=${local.atlantis_endpoint}"
  ]
  networks_advanced {
    name = "atlantis"
  }
}

resource "docker_container" "atlantis" {
  image    = "ghcr.io/runatlantis/atlantis:${var.atlantis_version}"
  name     = var.atlantis_name
  hostname = var.atlantis_name
  depends_on = [
    docker_container.ngrok
  ]
  ports {
    internal = var.atlantis_port
    external = var.atlantis_port
  }
  env = [

  ]
  networks_advanced {
    name = "atlantis"
  }
}
