terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm",
      version = ">= 2.91.0"
    }
  }
}

resource "azurerm_storage_account" "storageact" {
  name                     = var.appname
  resource_group_name      = var.resource_group.name
  location                 = var.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "appserviceplan" {
  name                = var.appname
  resource_group_name      = var.resource_group.name
  location                 = var.resource_group.location
  kind                = "FunctionApp"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_function_app" "functionapp" {
  name                       = var.appname
  resource_group_name        = var.resource_group.name
  location                   = var.resource_group.location
  app_service_plan_id        = azurerm_app_service_plan.appserviceplan.id
  storage_account_name       = azurerm_storage_account.storageact.name
  storage_account_access_key = azurerm_storage_account.storageact.primary_access_key
  app_settings = var.app_settings
  version = "~4"
}