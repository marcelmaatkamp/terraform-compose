variable "confluent_version" {
  default = "7.0.1"
}
variable "zookeeper_hostname" {
  default = "zookeeper"
}
variable "zookeeper_port" {
  default = 2181
}

variable "broker_internal_hostname" {
  default = "broker'"
}
variable "broker_internal_port" {
  default = 29092
}
variable "broker_external_hostname" {
  default = "localhost"
}
variable "broker_external_port" {
  default = 9092
}
variable "broker_jmx_hostname" {
  default = "localhost"
}
variable "broker_jmx_port" {
  default = 9101
}

variable "schema_registry_hostname" {
  default = "schema-registry"
}

variable "schema_registry_port" {
  default = 8081
}

variable "rest_proxy_hostname" {
  default = "rest-proxy"
}
variable "rest_proxy_port" {
  default = 8082
}

variable "ksql_server_hostname" {
  default = "ksql-server"
}
variable "ksql_server_port" {
  default = 8088
}

variable "connect_hostname" {
  default = "connect"
}
variable "connect_port" {
  default = 8083
}

variable "kafka_ui_hostname" {
  default = "kafka-ui"
}
variable "kafka_ui_port" {
  default = 8080
}
