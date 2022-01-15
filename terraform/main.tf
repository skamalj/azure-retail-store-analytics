terraform {
  backend "azurerm" {
    resource_group_name  = "myrg"
    // This is provided using terraform init -backend-config="key=value"
    storage_account_name = "myterraformaccount"
    container_name       = "tfstate"
    key                  = "demo.retail"
  }
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm",
      version = ">= 2.91.0"
    }
  }
}

provider "azurerm" {
  environment = "public"
  features {
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    key_vault {
     purge_soft_delete_on_destroy = false 
     recover_soft_deleted_key_vaults = true
    }
  }
}

resource "azurerm_resource_group" "eventshubrg" {
  name     = "eventshubrg"
  location = "West Europe"
}

resource "azurerm_eventhub_namespace" "eventhubns" {
  name                = "eventhubnswesteu"
  location            = azurerm_resource_group.eventshubrg.location
  resource_group_name = azurerm_resource_group.eventshubrg.name
  sku                 = "Standard"
  capacity            = 2
  maximum_throughput_units = 4
  auto_inflate_enabled = true
}

resource "azurerm_eventhub" "source" {
  name                = "source"
  namespace_name      = azurerm_eventhub_namespace.eventhubns.name
  resource_group_name = azurerm_resource_group.eventshubrg.name
  partition_count     = 8
  message_retention   = 1
}

resource "azurerm_eventhub" "sink" {
  name                = "sink"
  namespace_name      = azurerm_eventhub_namespace.eventhubns.name
  resource_group_name = azurerm_resource_group.eventshubrg.name
  partition_count     = 8
  message_retention   = 1
}

resource "azurerm_eventhub_consumer_group" "sourcecgasa" {
  name                = "sourcecgasa"
  namespace_name      = azurerm_eventhub_namespace.eventhubns.name
  eventhub_name       = azurerm_eventhub.source.name
  resource_group_name = azurerm_resource_group.eventshubrg.name
}