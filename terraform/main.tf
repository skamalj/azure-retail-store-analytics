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

resource "azurerm_stream_analytics_job" "createaggregate" {
  name                                     = "CreateAggregate"
  resource_group_name                      = azurerm_resource_group.eventshubrg.name
  location                                 = azurerm_resource_group.eventshubrg.location
  compatibility_level                      = "1.2"
  data_locale                              = "en-US"
  events_late_arrival_max_delay_in_seconds = 10
  events_out_of_order_max_delay_in_seconds = 10
  events_out_of_order_policy               = "Drop"
  output_error_policy                      = "Drop"
  streaming_units                          = 3
  transformation_query = file("../ASAYBSummary/ASAYBSummary.asaql")

  provisioner "local-exec" {
    when = destroy
    command = "az stream-analytics job stop  --job-name CreateAggregate --resource-group eventshubrg"
  }
}

resource "azurerm_stream_analytics_stream_input_eventhub" "asasource" {
  name                         = "myeventhub"
  stream_analytics_job_name    = azurerm_stream_analytics_job.createaggregate.name
  resource_group_name          = azurerm_resource_group.eventshubrg.name
  eventhub_consumer_group_name = azurerm_eventhub_consumer_group.sourcecgasa.name
  eventhub_name                = azurerm_eventhub.source.name
  servicebus_namespace         = azurerm_eventhub_namespace.eventhubns.name
  shared_access_policy_key     = azurerm_eventhub_namespace.eventhubns.default_primary_key
  shared_access_policy_name    = "RootManageSharedAccessKey"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }
}

resource "azurerm_stream_analytics_output_eventhub" "YBsink" {
  name                      = "YBsink"
  stream_analytics_job_name = azurerm_stream_analytics_job.createaggregate.name
  resource_group_name       = azurerm_resource_group.eventshubrg.name
  eventhub_name             = azurerm_eventhub.sink.name
  servicebus_namespace      = azurerm_eventhub_namespace.eventhubns.name
  shared_access_policy_key  = azurerm_eventhub_namespace.eventhubns.default_primary_key
  shared_access_policy_name = "RootManageSharedAccessKey"

  serialization {
    type = "Json"
    format = "Array"
    encoding = "UTF8"
  }
}

resource "azurerm_log_analytics_workspace" "retaildemolaws" {
  name                = "retaildemo-la-ws"
  resource_group_name = azurerm_resource_group.eventshubrg.name
  location            = azurerm_resource_group.eventshubrg.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "retaildemoappinsights" {
  name                = "retaildemo-appinsights"
  resource_group_name = azurerm_resource_group.eventshubrg.name
  location            = azurerm_resource_group.eventshubrg.location
  workspace_id        = azurerm_log_analytics_workspace.retaildemolaws.id
  application_type    = "Node.JS"
}

module "ybsummary" {
  source = "./functionapp"
  appname = "ybsummary"
  resource_group = azurerm_resource_group.eventshubrg
  app_settings = merge(var.app_settings, 
    {
      "eventhubns.connectionstring" = azurerm_eventhub_namespace.eventhubns.default_primary_connection_string
      "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.retaildemoappinsights.instrumentation_key
    })
}

module "ybrawcql" {
  source = "./functionapp"
  appname = "ybrawcql"
  resource_group = azurerm_resource_group.eventshubrg
  app_settings = merge(var.app_settings, 
    {
      "eventhubns.connectionstring" = azurerm_eventhub_namespace.eventhubns.default_primary_connection_string
      "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.retaildemoappinsights.instrumentation_key
    })
}

resource "null_resource" "example1" {
  provisioner "local-exec" {
    command = <<COMMANDS
    cd ../function-summary
    func azure functionapp fetch-app-settings ybsummary
    func azure functionapp publish ybsummary
    cd ../function-rawyb
    func azure functionapp fetch-app-settings ybrawcql
    func azure functionapp publish ybrawcql
    az stream-analytics job start  --job-name CreateAggregate --resource-group eventshubrg
COMMANDS
  }
  depends_on = [
    module.ybsummary,
    module.ybrawcql,
    resource.azurerm_stream_analytics_job.createaggregate
  ]
}



