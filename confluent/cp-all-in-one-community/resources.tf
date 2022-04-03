# https://raw.githubusercontent.com/confluentinc/cp-all-in-one/7.0.1-post/cp-all-in-one-community/docker-compose.yml

locals { 
  confluent_version = "7.0.1"

  zookeeper_hostname = "zookeeper"
  zookeeper_port = 2181
  zookeeper_endpoint = "${local.zookeeper_hostname}:${local.zookeeper_port}"
  
  broker_internal_hostname = "broker"
  broker_internal_port = 29092
  broker_internal_endpoint = "${local.broker_internal_hostname}:${local.broker_internal_port}"

  broker_external_hostname = "localhost"
  broker_external_port = 9092
  broker_external_endpoint = "${local.broker_external_hostname}:${local.broker_external_port}"
  
  broker_jmx_hostname = "localhost"
  broker_jmx_port = 9101
  broker_jmx_endpoint = "${local.broker_jmx_hostname}:${local.broker_jmx_port}"
}

# zookeeper
#  HEALTHCHECK CMD [ $(echo ruok | nc 127.0.0.1:2181) == "imok" ] || exit 1
resource "docker_container" "zookeeper" {
  image = "confluentinc/cp-zookeeper:${local.confluent_version}"
  name  = "${local.zookeeper_hostname}"
  hostname = "${local.zookeeper_hostname}"
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
  image = "confluentinc/cp-kafka:${local.confluent_version}"
  name  = "${local.broker_internal_hostname}"
  hostname = "${local.broker_internal_hostname}"
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