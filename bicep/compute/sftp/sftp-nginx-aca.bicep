param storageAccountPrefix string
param storageAccountType string = 'Standard_LRS'
param sftpFileShareName string = 'sftpfileshare'

param logAnalyticsName string = 'sftp-nginx-${toLower(resourceGroup().name)}'

param containerEnvName string = 'sftp-nginx-env'
param containerAppName string = 'sftp-nginx-app'
param minReplica int = 1
param maxReplica int = 2
param nginxContainerRegistry string = 'sftpmariner.azurecr.io'
param nginxContainerRegistryUser string = 'sftpmariner'
@secure()
param nginxContainerRegistryPassword string

param sftpUser string = 'sftp'
@secure()
param sftpPassword string
param location string = resourceGroup().location

var sftpContainerName = 'sftp'
var nginxContainerName = 'nginx'
var sftpContainerImage = 'atmoz/sftp:latest'
var nginxContainerImage = '${nginxContainerRegistry}/nginx-sftp:latest'
var sftpEnvVariable = '${sftpUser}:${sftpPassword}:1001'
var storageAccountName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku:{
    name: storageAccountType
  }
}

resource sftpFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: toLower('${storageAccount.name}/default/${sftpFileShareName}')
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku:{
      name: 'PerGB2018'
    }
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerAppEnvSftpStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  name: '${sftpContainerName}-storage'
  parent: containerAppEnv
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: sftpFileShareName
      accessMode: 'ReadWrite'
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      secrets: [
        {
          name: 'nginxregpwd'
          value: nginxContainerRegistryPassword
        }
        {
          name: 'sftpenvvariable'
          value: sftpEnvVariable
        }
      ]
      ingress: {
        external: true
        targetPort: 2222
        allowInsecure: true
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: nginxContainerRegistry
          username: nginxContainerRegistryUser
          passwordSecretRef: 'nginxregpwd'
        }
      ]
    }
    template: {
      revisionSuffix: 'secondrevision'
      containers: [
        {
          name: nginxContainerName
          image: nginxContainerImage
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
        {
          name: sftpContainerName
          image: sftpContainerImage
          env: [
            {
              name: 'SFTP_USERS'
              secretRef: 'sftpenvvariable'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
          volumeMounts: [
            {
              mountPath: '/home/${sftpUser}/upload'
              volumeName: 'sftp-volume'
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplica
        maxReplicas: maxReplica
      }
      volumes: [
        {
          name: 'sftp-volume'
          storageType: 'AzureFile'
          storageName: containerAppEnvSftpStorage.name
        }
      ]
    }
  }
}
