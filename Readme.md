# 概要

App ServiceとAzure OpenAIとCosmosDBを使ってプライベートエンドポイント経由で通信するためのサンプルです。

## 構成

![Architecture](./docs/images/Architecture.png)

## Task

- [x]App ServiceとCosmosDBのインフラと共に、サンプルアプリをデプロイする
- [x]Azure OpenAIのデプロイ
- []App ServiceとAzure OpenAIの通信をプライベートエンドポイント経由で行う
- []App ServiceとCosmosDBの通信をプライベートエンドポイント経由で行う

## 参考

[app-service-regional-vnet-integration](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.web/app-service-regional-vnet-integration)

[cosmosdb-webapp](https://github.com/Azure/azure-quickstart-templates/tree/master/quickstarts/microsoft.documentdb/cosmosdb-webapp)

[azd-starter-bicep](https://github.com/Azure-Samples/azd-starter-bicep/tree/main/infra/core)