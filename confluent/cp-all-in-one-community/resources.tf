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

  ksql_server_hostname = "ksql-server"
  ksql_server_port     = 8088
  ksql_server_endpoint = "${local.ksql_server_hostname}:${local.ksql_server_port}"

  connect_hostname = "connect"
  connect_port     = 8083
  connect_endpoint = "${local.connect_hostname}:${local.connect_port}"

  kafka_ui_hostname = "kafka-ui"
  kafka_ui_port     = 8080
}

resource "docker_network" "kafka" {
  name = "kafka"
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
  networks_advanced {
    name = "kafka"
  }
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
  networks_advanced {
    name = "kafka"
  }
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
  networks_advanced {
    name = "kafka"
  }
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
    "KAFKA_REST_HOST_NAME=rest-proxy",
    "KAFKA_REST_BOOTSTRAP_SERVERS='${local.broker_internal_endpoint}'",
    "KAFKA_REST_LISTENERS='http://0.0.0.0:${local.rest_proxy_port}'",
    "KAFKA_REST_SCHEMA_REGISTRY_URL='http://${local.schema_registry_endpoint}'"
  ]
  networks_advanced {
    name = "kafka"
  }
}

# connect

resource "docker_container" "connect" {
  image    = "cnfldemos/kafka-connect-datagen:0.5.0-6.2.0"
  name     = local.connect_hostname
  hostname = local.connect_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = local.connect_port
    external = local.connect_port
  }
  env = [
    "CONNECT_BOOTSTRAP_SERVERS='${local.broker_internal_endpoint}'",
    "CONNECT_REST_ADVERTISED_HOST_NAME=${local.connect_hostname}",
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
  name     = local.ksql_server_hostname
  hostname = local.ksql_server_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry
  ]
  ports {
    internal = local.ksql_server_port
    external = local.ksql_server_port
  }
  env = [
    "KSQL_CONFIG_DIR=/etc/ksql",
    "KSQL_BOOTSTRAP_SERVERS=${local.broker_internal_endpoint}",
    "KSQL_HOST_NAME=${local.ksql_server_hostname}",
    "KSQL_LISTENERS=http://0.0.0.0:${local.ksql_server_port}",
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
  name     = local.kafka_ui_hostname
  hostname = local.kafka_ui_hostname
  depends_on = [
    docker_container.broker,
    docker_container.schema-registry,
    docker_container.connect,
    docker_container.ksqldb-server
  ]
  ports {
    internal = local.ksql_server_port
    external = local.ksql_server_port
  }
  env = [
    "KAFKA_CLUSTERS_0_NAME=local",
    "KAFKA_CLUSTERS_0_ZOOKEEPER=${local.zookeeper_endpoint}",
    "KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=${local.broker_internal_endpoint}",
    "KAFKA_CLUSTERS_0_JMXPORT=${local.broker_jmx_port}",
    "KAFKA_CLUSTERS_0_SCHEMAREGISTRY=http://${local.schema_registry_endpoint}",
    "KAFKA_CLUSTERS_0_KSQLDBSERVER=http://${local.ksql_server_endpoint}",
    "KAFKA_CLUSTERS_0_KAFKACONNECT_0_NAME=connect-0",
    "KAFKA_CLUSTERS_0_KAFKACONNECT_0_ADDRESS=http://${local.connect_endpoint}"
  ]
  networks_advanced {
    name = "kafka"
  }
}
