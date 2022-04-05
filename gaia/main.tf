locals { 

  ngrok_name = "ngrok"
  ngrok_port = 4040
  ngrok_endpoint = "${local.ngrok_name}:${local.ngrok_port}"

  atlantis_version = "v0.19.2"
  atlantis_name = "atlantis"
  atlantis_port = 4141
  atlantis_endpoint = "${local.atlantis_name}:${local.atlantis_port}"
}

resource "docker_network" "kafka" {
  name = "atlantis"
}

resource "docker_container" "ngrok" {
  image    = ""
  name     = local.ngrok_name
  hostname = local.ngrok_name
  ports {
    internal = local.ngrok_port
    external = local.ngrok_port
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
  image    = "ghcr.io/runatlantis/atlantis:${local.atlantis_version}"
  name     = local.atlantis_name
  hostname = local.atlantis_name
  depends_on = [
    docker_container.ngrok
  ]
  ports {
    internal = local.atlantis_port
    external = local.atlantis_port
  }
  env = [
    "ZOOKEEPER_CLIENT_PORT=${local.zookeeper_port}",
    "ZOOKEEPER_TICK_TIME=2000"
  ]
  networks_advanced {
    name = "kafka"
  }
}