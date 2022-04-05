locals { 
  ngrok_name = "ngrok"
  ngrok_port = 4040
  ngrok_endpoint = "${local.ngrok_name}:${local.ngrok_port}"

  mongodb_name = "mongodb"
  mongodb_port = 27017
  mongodb_endpoint = "${local.mongodb_name}:${local.mongodb_port}"
  mongodb_version = "4.4"

  gaia_name = "gaia"
  gaia_port = 8080
  gaia_endpoint = "${local.gaia_name}:${local.gaia_port}"
  gaia_api_password = "123456"
  gaia_version = "v2.2.0"

  runner_name = "runner"
}

resource "docker_network" "gaia" {
  name = "gaia"
}

resource "docker_container" "ngrok" {
  image    = "mongo:4.4"
  name     = local.ngrok_name
  hostname = local.ngrok_name
  ports {
    internal = local.ngrok_port
    external = local.ngrok_port
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
  image    = "mongo:${local.mongodb_version}"
  name     = local.mongodb_name
  hostname = local.mongodb_name
  ports {
    internal = local.mongodb_port
    external = local.mongodb_port
  }
  env = [

  ]
  networks_advanced {
    name = "gaia"
  }
}

resource "docker_container" "gaia" {
  image    = "gaiaapp/gaia:${local.gaia_version}"
  name     = local.gaia_name
  hostname = local.gaia_name
  depends_on = [
    docker_container.ngrok
  ]
  ports {
    internal = local.gaia_port
    external = local.gaia_port
  }
  env = [
    "GAIA_MONGODB_URI=mongodb://mongo/gaia",
    "GAIA_EXTERNAL_URL=http://172.17.0.1:8080",
    "GAIA_RUNNER_API_PASSWORD=${local.gaia_api_password}"
  ]
  networks_advanced {
    name = "gaia"
  }
}

resource "docker_container" "runner" {
  image    = "gaiaapp/runner:${local.gaia_version}"
  name     = local.runner_name
  hostname = local.runner_name
  depends_on = [
    docker_container.ngrok
  ]
  volumes { 
    host_path = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  env = [
    "GAIA_URL=http://${local.gaia_endpoint}",
    "GAIA_RUNNER_API_PASSWORD=${local.gaia_api_password}"
  ]
  networks_advanced {
    name = "gaia"
  }
}
