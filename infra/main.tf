provider "azurerm" {
  features {}
}

# Add random suffix for uniqueness
resource "random_id" "suffix" {
  byte_length = 4
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-shadowops-ai"
  location = "East US"
}

# Globally unique Storage Account
resource "azurerm_storage_account" "sa" {
  name                     = "shadowops${random_id.suffix.hex}"  # ✅ unique
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App Service Plan (use Basic to avoid Dynamic quota issue)
resource "azurerm_app_service_plan" "plan" {
  name                = "shadowops-plan-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"

  sku {
    tier = "Basic"   # ✅ use Basic if Dynamic fails
    size = "B1"
  }
}

# Application Insights
resource "azurerm_application_insights" "insights" {
  name                = "shadowops-ai-insights-${random_id.suffix.hex}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Function App
resource "azurerm_function_app" "func" {
  name                       = "shadowops-function-${random_id.suffix.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  version                    = "~4"
  os_type                    = "linux"
  https_only                 = true

  app_settings = {
    AzureWebJobsStorage             = azurerm_storage_account.sa.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME       = "python"
    APPINSIGHTS_INSTRUMENTATIONKEY = azurerm_application_insights.insights.instrumentation_key
    OPENAI_API_KEY                 = var.openai_api_key
  }
}

# Event Hub Namespace (must be globally unique)
resource "azurerm_eventhub_namespace" "ehns" {
  name                = "shadowops-eh-ns-${random_id.suffix.hex}"  # ✅ unique
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1
}

# Event Hub
resource "azurerm_eventhub" "eh" {
  name                = "shadowops-events"
  namespace_name      = azurerm_eventhub_namespace.ehns.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 2
  message_retention   = 1
}
