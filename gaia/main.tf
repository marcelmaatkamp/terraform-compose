locals {
  ngrok_endpoint   = "${var.ngrok_name}:${var.ngrok_port}"
  mongodb_endpoint = "${var.mongodb_name}:${var.mongodb_port}"
  gaia_endpoint    = "${var.gaia_name}:${var.gaia_port}"
}

resource "docker_network" "gaia" {
  name = "gaia"
}

resource "docker_container" "ngrok" {
  image    = var.ngrok_image
  name     = var.ngrok_name
  hostname = var.ngrok_name
  ports {
    internal = var.ngrok_port
    external = var.ngrok_port
  }
  env = [
    "NGROK_PROTOCOL=http",
    "NGROK_PORT=${local.gaia_endpoint}"
  ]
  networks_advanced {
    name = "gaia"
  }
}

resource "docker_container" "mongodb" {
  image    = "mongo:${var.mongodb_version}"
  name     = var.mongodb_name
  hostname = var.mongodb_name
  ports {
    internal = var.mongodb_port
    external = var.mongodb_port
  }
  env = [

  ]
  networks_advanced {
    name = "gaia"
  }
}

resource "docker_container" "gaia" {
  image    = "gaiaapp/gaia:${var.gaia_version}"
  name     = var.gaia_name
  hostname = var.gaia_name
  depends_on = [
    docker_container.ngrok
  ]
  ports {
    internal = var.gaia_port
    external = var.gaia_port
  }
  env = [
    "GAIA_MONGODB_URI=mongodb://${local.mongodb_endpoint}/gaia",
    "GAIA_EXTERNAL_URL=http://172.17.0.1:8080",
    "GAIA_RUNNER_API_PASSWORD=${var.gaia_api_password}"
  ]
  networks_advanced {
    name = "gaia"
  }
}

resource "docker_container" "runner" {
  image    = "gaiaapp/runner:${var.gaia_version}"
  name     = var.runner_name
  hostname = var.runner_name
  depends_on = [
    docker_container.ngrok
  ]
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  env = [
    "GAIA_URL=http://${local.gaia_endpoint}",
    "GAIA_RUNNER_API_PASSWORD=${var.gaia_api_password}"
  ]
  networks_advanced {
    name = "gaia"
  }
}
