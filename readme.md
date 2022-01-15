### Code in this repository is for building solution shown in picture below.

![Architecture](resources/AzureEventHUb-ASA-Yugabyte-Grafana.drawio.png)

### Demo and code explanation is in this blog

# Deploying this app

## Create EventHubs

* Run terraform apply from `terraform` folder to create eventhub namespace, eventhubs and consumer groups
* Get connection string for eventhub NS
```
terraform output source_connection_string
```

## Deploy the functions

** Read about func tools [here](https://docs.microsoft.com/en-us/azure/azure-functions/functions-core-tools-reference?tabs=v2#func-azure-functionapp-fetch-app-settings)
```
cd function-summary
func azure functionapp publish ybsummary
func azure functionapp fetch-app-settings ybsummary # This creates local settings file from current app settings
cd ../function-rawyb
func azure functionapp publish ybrawsql 
func azure functionapp fetch-app-settings ybrawsql
```
* Update local settings file for both function to add below YB values
```
"eventhubns.connectionstring":  <String you got from eventhub NS>
"yugabyte.admin-user": 
"yugabyte.admin-password": 
"yugabyte.host": 
"yugabyte.root-crt": <Use this command and then paste here - echo $(cat root.crt)>
```
* Now upload the settings back to Azure using below command for both functions
```
func azure functionapp publish ybrawsql --publish-local-settings
```

## Create Stream Analytics Job
* Install Azure Stream Analytics Extension as described [here](https://docs.microsoft.com/en-us/azure/stream-analytics/quick-create-visual-studio-code)
* Open the project in VSCode
* Go To ASAYBSummary -> Inputs, and click on myeventhub.json.  Now click on the greyed text for each option to select your values
* Do same for output - YBSink.json
* No select ASAYBSummary.asaql and publish to azure

## Now start your [generator](https://github.com/skamalj/datagenerator) based on cconfig file provided in resources folder

## Create your grafana dashboard by importing the json file from resources folder. 
* You will have to setup your datasource for yugabyte SQL (Using PostgreSQL plugin)