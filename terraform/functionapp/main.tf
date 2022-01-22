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

resource "azurerm_monitor_autoscale_setting" "appservicescalerule" {
  name                = var.appname
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  target_resource_id  = azurerm_app_service_plan.appserviceplan.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.appserviceplan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 85
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.appserviceplan.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 35
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "example" {
  name               = var.appname
  target_resource_id = azurerm_function_app.functionapp.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  log {
    category = "FunctionAppLogs"
    retention_policy {
      enabled = true
      days    = 7
    }
  }

  metric {
    category = "AllMetrics"
    retention_policy {
      enabled = true
      days    = 7
    }
  }
}