param storageAccountPrefix string
param storageAccountType string = 'Standard_LRS'
param sftpFileShareName string = 'sftpfileshare'
param nginxFileShareName string = 'nginxfileshare'

param logAnalyticsName string = 'sftp-nginx-${toLower(resourceGroup().name)}'

param containerEnvName string = 'sftp-nginx-env'
param containerAppName string = 'sftp-nginx-app'
param minReplica int = 1
param maxReplica int = 2
var sftpContainerName = 'sftp'
var nginxContainerName = 'nginx'
var sftpContainerImage = 'atmoz/sftp:latest'
var nginxContainerImage = 'nginx:latest'

param sftpUser string = 'sftp'
@secure()
param sftpPassword string
param location string = resourceGroup().location


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

resource nginxFileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: toLower('${storageAccount.name}/default/${nginxFileShareName}')
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

resource containerAppEnvNginxStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  name: '${nginxContainerName}-storage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: nginxFileShareName
      accessMode: 'ReadOnly'
    }
  }
}

resource containerAppEnvSftpStorage 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
  name: '${sftpContainerName}-storage'
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
    }
    template: {
      revisionSuffix: 'firstrevision'
      containers: [
        {
          name: nginxContainerName
          image: nginxContainerImage
          resources: {
            cpu: json('.5')
            memory: '.5Gi'
          }
          volumeMounts: [
            {
                mountPath: '/etc/nginx'
                volumeName: 'nginx-volume'
            }
          ]
        }
        {
          name: sftpContainerName
          image: sftpContainerImage
          env: [
            {
              name: 'SFTP_USERS'
              value: sftpEnvVariable
            }
          ]
          resources: {
            cpu: json('.5')
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
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      volumes: [
        {
          name: containerAppEnvNginxStorage.name
          storageType: 'AzureFile'
          storageName: '${nginxContainerName}-storage'
        }
        {
          name: containerAppEnvSftpStorage.name
          storageType: 'AzureFile'
          storageName: '${sftpContainerName}-storage'
        }
      ]
    }
  }
}
