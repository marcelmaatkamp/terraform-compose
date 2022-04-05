# https://raw.githubusercontent.com/confluentinc/cp-all-in-one/7.0.1-post/cp-all-in-one-community/docker-compose.yml

locals {
  zookeeper_endpoint       = "${var.zookeeper_hostname}:${var.zookeeper_port}"
  broker_internal_endpoint = "${var.broker_internal_hostname}:${var.broker_internal_port}"
  broker_external_endpoint = "${var.broker_external_hostname}:${var.broker_external_port}"
  broker_jmx_endpoint      = "${var.broker_jmx_hostname}:${var.broker_jmx_port}"
  schema_registry_endpoint = "${var.schema_registry_hostname}:${var.schema_registry_port}"
  rest_proxy_endpoint      = "${var.rest_proxy_hostname}:${var.rest_proxy_port}"
  ksql_server_endpoint     = "${var.ksql_server_hostname}:${var.ksql_server_port}"
  connect_endpoint         = "${var.connect_hostname}:${var.connect_port}"
}

resource "docker_network" "kafka" {
  name = "kafka"
}

# zookeeper
#  HEALTHCHECK CMD [ $(echo ruok | nc 127.0.0.1:2181) == "imok" ] || exit 1
resource "docker_container" "zookeeper" {
  image    = "confluentinc/cp-zookeeper:${var.confluent_version}"
  name     = var.zookeeper_hostname
  hostname = var.zookeeper_hostname
  ports {
    internal = var.zookeeper_port
    external = var.zookeeper_port
  }
  env = [
    "ZOOKEEPER_CLIENT_PORT=${var.zookeeper_port}",
    "ZOOKEEPER_TICK_TIME=2000"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# broker
#  HEALTHCHECK CMD netstat -an | grep 9092 > /dev/null; if [ 0 != $? ]; then exit 1; fi;
resource "docker_container" "broker" {
  image    = "confluentinc/cp-kafka:${var.confluent_version}"
  name     = var.broker_internal_hostname
  hostname = var.broker_internal_hostname
  depends_on = [
    docker_container.zookeeper
  ]
  ports {
    internal = var.broker_internal_port
    external = var.broker_internal_port
  }
  ports {
    internal = var.broker_external_port
    external = var.broker_external_port
  }
  ports {
    internal = var.broker_jmx_port
    external = var.broker_jmx_port
  }
  env = [
    "KAFKA_BROKER_ID=1",
    "KAFKA_ZOOKEEPER_CONNECT=${local.zookeeper_endpoint}",
    "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT",
    "KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://${local.broker_internal_endpoint},PLAINTEXT_HOST://${local.broker_external_endpoint}",
    "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
    "KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1",
    "KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1",
    "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0",
    "KAFKA_JMX_PORT=${var.broker_jmx_port}",
    "KAFKA_JMX_HOSTNAME=${var.broker_internal_hostname}"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# schema-registry

resource "docker_container" "schema-registry" {
  image    = "confluentinc/cp-schema-registry:${var.confluent_version}"
  name     = var.schema_registry_hostname
  hostname = var.schema_registry_hostname
  depends_on = [
    docker_container.broker
  ]
  ports {
    internal = var.schema_registry_port
    external = var.schema_registry_port
  }
  env = [
    "SCHEMA_REGISTRY_HOST_NAME=${var.schema_registry_hostname}",
    "SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=${local.broker_internal_endpoint}",
    "SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:${var.schema_registry_port}"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# rest-proxy 

resource "docker_container" "rest-proxy" {
  image    = "confluentinc/cp-kafka-rest:${var.confluent_version}"
  name     = var.rest_proxy_hostname
  hostname = var.rest_proxy_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = var.rest_proxy_port
    external = var.rest_proxy_port
  }
  env = [
    "KAFKA_REST_HOST_NAME=rest-proxy",
    "KAFKA_REST_BOOTSTRAP_SERVERS=${local.broker_internal_endpoint}",
    "KAFKA_REST_LISTENERS=http://0.0.0.0:${var.rest_proxy_port}",
    "KAFKA_REST_SCHEMA_REGISTRY_URL=http://${local.schema_registry_endpoint}"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# connect

resource "docker_container" "connect" {
  image    = "cnfldemos/kafka-connect-datagen:0.5.0-6.2.0"
  name     = var.connect_hostname
  hostname = var.connect_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = var.connect_port
    external = var.connect_port
  }
  env = [
    "CONNECT_BOOTSTRAP_SERVERS=${local.broker_internal_endpoint}",
    "CONNECT_REST_ADVERTISED_HOST_NAME=${var.connect_hostname}",
    "CONNECT_GROUP_ID=compose-connect-group",
    "CONNECT_CONFIG_STORAGE_TOPIC=docker-connect-configs",
    "CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR=1",
    "CONNECT_OFFSET_FLUSH_INTERVAL_MS=10000",
    "CONNECT_OFFSET_STORAGE_TOPIC=docker-connect-offsets",
    "CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR=1",
    "CONNECT_STATUS_STORAGE_TOPIC=docker-connect-status",
    "CONNECT_STATUS_STORAGE_REPLICATION_FACTOR=1",
    "CONNECT_KEY_CONVERTER=org.apache.kafka.connect.storage.StringConverter",
    "CONNECT_VALUE_CONVERTER=io.confluent.connect.avro.AvroConverter",
    "CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL=http://${local.schema_registry_endpoint}",
    "CONNECT_PLUGIN_PATH='/usr/share/java,/usr/share/confluent-hub-components'",
    "CONNECT_LOG4J_LOGGERS=org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR",
  ]
  networks_advanced {
    name = "kafka"
  }
}

# ksql-server

resource "docker_container" "ksqldb-server" {
  image    = "confluentinc/cp-ksqldb-server:7.0.1"
  name     = var.ksql_server_hostname
  hostname = var.ksql_server_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = var.ksql_server_port
    external = var.ksql_server_port
  }
  env = [
    "KSQL_CONFIG_DIR=/etc/ksql",
    "KSQL_BOOTSTRAP_SERVERS=${local.broker_internal_endpoint}",
    "KSQL_HOST_NAME=${var.ksql_server_hostname}",
    "KSQL_LISTENERS=http://0.0.0.0:${var.ksql_server_port}",
    "KSQL_CACHE_MAX_BYTES_BUFFERING=0",
    "KSQL_KSQL_SCHEMA_REGISTRY_URL=http://${local.schema_registry_endpoint}",
    "KSQL_PRODUCER_INTERCEPTOR_CLASSES=io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor",
    "KSQL_CONSUMER_INTERCEPTOR_CLASSES=io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor",
    "KSQL_KSQL_CONNECT_URL=http://${local.connect_endpoint}",
    "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR=1",
    "KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE=true",
    "KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE=true"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# kafka-ui
#  https://github.com/provectus/kafka-ui/tree/master/documentation/compose
#  https://github.com/provectus/kafka-ui/issues/1782

resource "docker_container" "kafka-ui" {
  image    = "provectuslabs/kafka-ui:latest"
  name     = var.kafka_ui_hostname
  hostname = var.kafka_ui_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry,
    docker_container.connect,
    docker_container.ksqldb-server
  ]
  ports {
    internal = var.kafka_ui_port
    external = var.kafka_ui_port
  }
  env = [
    "KAFKA_CLUSTERS_0_NAME=local",
    "KAFKA_CLUSTERS_0_ZOOKEEPER=${local.zookeeper_endpoint}",
    "KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=${local.broker_internal_endpoint}",
    "KAFKA_CLUSTERS_0_JMXPORT=${var.broker_jmx_port}",
    "KAFKA_CLUSTERS_0_SCHEMAREGISTRY=http://${local.schema_registry_endpoint}",
    "KAFKA_CLUSTERS_0_KSQLDBSERVER=http://${local.ksql_server_endpoint}",
    "KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME=connect-0",
    "KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS=http://${local.connect_endpoint}"
  ]
  networks_advanced {
    name = "kafka"
  }
}
