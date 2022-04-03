# https://raw.githubusercontent.com/confluentinc/cp-all-in-one/7.0.1-post/cp-all-in-one-community/docker-compose.yml

locals {
  confluent_version = "7.0.1"

  zookeeper_hostname = "zookeeper"
  zookeeper_port     = 2181
  zookeeper_endpoint = "${local.zookeeper_hostname}:${local.zookeeper_port}"

  broker_internal_hostname = "broker"
  broker_internal_port     = 29092
  broker_internal_endpoint = "${local.broker_internal_hostname}:${local.broker_internal_port}"

  broker_external_hostname = "localhost"
  broker_external_port     = 9092
  broker_external_endpoint = "${local.broker_external_hostname}:${local.broker_external_port}"

  broker_jmx_hostname = "localhost"
  broker_jmx_port     = 9101
  broker_jmx_endpoint = "${local.broker_jmx_hostname}:${local.broker_jmx_port}"

  schema_registry_hostname = "schema-registry"
  schema_registry_port     = 8081
  schema_registry_endpoint = "${local.schema_registry_hostname}:${local.schema_registry_port}"

  rest_proxy_hostname = "rest-proxy"
  rest_proxy_port     = 8082
  rest_proxy_endpoint = "${local.rest_proxy_hostname}:${local.rest_proxy_port}"

}

# zookeeper
#  HEALTHCHECK CMD [ $(echo ruok | nc 127.0.0.1:2181) == "imok" ] || exit 1
resource "docker_container" "zookeeper" {
  image    = "confluentinc/cp-zookeeper:${local.confluent_version}"
  name     = local.zookeeper_hostname
  hostname = local.zookeeper_hostname
  ports {
    internal = local.zookeeper_port
    external = local.zookeeper_port
  }
  env = [
    "ZOOKEEPER_CLIENT_PORT=${local.zookeeper_port}",
    "ZOOKEEPER_TICK_TIME=2000"
  ]
}

# broker
#  HEALTHCHECK CMD netstat -an | grep 9092 > /dev/null; if [ 0 != $? ]; then exit 1; fi;
resource "docker_container" "broker" {
  image    = "confluentinc/cp-kafka:${local.confluent_version}"
  name     = local.broker_internal_hostname
  hostname = local.broker_internal_hostname
  depends_on = [
    docker_container.zookeeper
  ]
  ports {
    internal = local.broker_internal_port
    external = local.broker_internal_port
  }
  ports {
    internal = local.broker_external_port
    external = local.broker_external_port
  }
  ports {
    internal = local.broker_jmx_port
    external = local.broker_jmx_port
  }
  env = [
    "KAFKA_BROKER_ID=1",
    "KAFKA_ZOOKEEPER_CONNECT='${local.zookeeper_endpoint}'",
    "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT",
    "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://${local.broker_internal_endpoint},PLAINTEXT_HOST://${local.broker_external_endpoint}",
    "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
    "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1",
    "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1",
    "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0",
    "KAFKA_JMX_PORT=${local.broker_jmx_port}",
    "KAFKA_JMX_HOSTNAME=${local.broker_internal_hostname}"
  ]
}

# schema-registry

resource "docker_container" "schema-registry" {
  image    = "confluentinc/cp-schema-registry:${local.confluent_version}"
  name     = local.schema_registry_hostname
  hostname = local.schema_registry_hostname
  depends_on = [
    docker_container.broker
  ]
  ports {
    internal = local.schema_registry_port
    external = local.schema_registry_port
  }
  env = [
    "SCHEMA_REGISTRY_HOST_NAME=${local.schema_registry_hostname}",
    "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS='${local.broker_internal_endpoint}'",
    "SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:${local.schema_registry_port}"
  ]
}

# rest-proxy 

resource "docker_container" "rest-proxy" {
  image    = "onfluentinc/cp-kafka-rest:${local.confluent_version}"
  name     = local.rest_proxy_hostname
  hostname = local.rest_proxy_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = local.rest_proxy_port
    external = local.rest_proxy_port
  }
  env = [
    "KAFKA_REST_HOST_NAME: rest-proxy",
    "KAFKA_REST_BOOTSTRAP_SERVERS: '${local.broker_internal_endpoint}'",
    "KAFKA_REST_LISTENERS: 'http://0.0.0.0:${local.rest_proxy_port}'",
    "KAFKA_REST_SCHEMA_REGISTRY_URL: 'http://${local.schema_registry_endpoint}'"
  ]
}

