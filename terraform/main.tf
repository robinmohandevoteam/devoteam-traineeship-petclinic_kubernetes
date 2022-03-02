# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  backend "azurerm" {
    resource_group_name   = "pers-robin_mohan-rg"
    storage_account_name  = "terraformbackend020322"
    container_name        = "tstate"
    key                   = "m9I4sNng6wey5dFAjVTcwcRgxdY0I5h2oq9dpe+Z+e7kW3Q8iih8h7pHuUdkYRzsAdxMMBUkf2W/vl67kD7LMw=="
}
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.13.1"
    }
}
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true
  features {}
}


variable "prefix" {
  default = "petclinictest"
}

variable "resource_group_name" {
  default = "pers-robin_mohan-rg"
}

variable "resource_group_location" {
    default = "West Europe"
}

resource "azurerm_kubernetes_cluster" "petclinictest" {
  name                = "${var.prefix}-aks1"
  location            = "${var.resource_group_location}"
  resource_group_name = "${var.resource_group_name}"
  dns_prefix          = "petclinictest"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "testing"
    pillar = "M Cloud"
    usage = "Devoteam related activities"

  }
}

# output "client_certificate" {
#   value = azurerm_kubernetes_cluster.petclinictest.kube_config.0.client_certificate
# }

# output "kube_config" {
#   value = azurerm_kubernetes_cluster.petclinictest.kube_config_raw

#   sensitive = true
# }

# output "kube_config" {
#   value = "${azurerm_kubernetes_cluster.petclinictest.kube_config_raw}"
# }

# output "host" {
#   value = "${azurerm_kubernetes_cluster.petclinictest.kube_config.0.host}"
# }


provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.petclinictest.kube_config.0.host
  username               = azurerm_kubernetes_cluster.petclinictest.kube_config.0.username
  password               = azurerm_kubernetes_cluster.petclinictest.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.petclinictest.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.petclinictest.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.petclinictest.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_namespace" "petclinictest" {
  metadata {
    annotations = {
      name = "petclinictest-ns"
    }

    labels = {
      app = "petclinictest"
    }

    name = "petclinictest-ns"
  }
}

resource "azurerm_role_assignment" "kubweb_to_acr" {
  scope                = "/subscriptions/41e50375-b926-4bc4-9045-348f359cf721/resourceGroups/pers-robin_mohan-rg/providers/Microsoft.ContainerRegistry/registries/petclinictest"
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.petclinictest.kubelet_identity[0].object_id
}

resource "kubernetes_deployment" "petclinictest" {
  metadata {
    name = "petclinictest"
    namespace = "petclinictest-ns"
    labels = {
      app = "petclinictest"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "petclinictest"
      }
    }

    template {
      metadata {
        labels = {
          app = "petclinictest"
        }
      }

      spec {
        container {
          image = "petclinictest.azurecr.io/jettypetclinic:latest"
          name  = "petclinictest"

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          port {
            container_port = 80
            name = "redis"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "petclinictest" {
  metadata {
    name = "petclinictest-lb"
    namespace = "petclinictest-ns"
  }
  spec {
    selector = {
      app = kubernetes_deployment.petclinictest.metadata.0.name
    }
    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

output "load_balancer_name" {
  value = local.lb_name
}

output "load_balancer_hostname" {
  value = kubernetes_service.example.status.0.load_balancer.0.ingress.0.hostname
}

output "load_balancer_info" {
  value = data.aws_elb.example
}