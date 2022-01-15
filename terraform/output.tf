output "source_connection_string" {
  value = azurerm_eventhub_namespace.eventhubns.default_primary_connection_string
  sensitive = true
}