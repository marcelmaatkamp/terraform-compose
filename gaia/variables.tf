variable "ngrok_image" { 
    type = string
    default = "wernight/ngrok:latest"
}
variable "ngrok_name" { 
    type = string
    default = "ngrok"
}
variable "ngrok_port" { 
    type = number
    default = 4040
}

variable "mongodb_name" {
    type = string
    default = "mongodb"
}
variable "mongodb_port" { 
    type = number
    default = 27017
}
variable "mongodb_version" { 
    type = string
    default = "4.4"
}

variable "gaia_name" { 
    type = string
    default = "gaia"
}
variable "gaia_port" { 
    type = number
    default = 8080
}

variable "gaia_api_password" { 
    type = string
    default = "123456"
}
variable "gaia_version" { 
    type = string
    default = "v2.2.0"
}

variable "runner_name" { 
    type = string
    default = "runner"
}
