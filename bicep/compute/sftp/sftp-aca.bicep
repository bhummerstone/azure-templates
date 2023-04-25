param storageAccountPrefix string
param storageAccountType string = 'Standard_LRS'
param sftpFileShareName string = 'sftpfileshare'

param logAnalyticsName string = 'sftp-${toLower(resourceGroup().name)}'

param vNetName string = 'sftp-vnet'
param vNetAddressPrefix string = '10.0.0.0/16'
param acaSubnetName string = 'aca-subnet'
param acaSubnetPrefix string = '10.0.0.0/21'

param containerEnvName string = 'sftp-env'
param containerAppName string = 'sftp-app'
param minReplica int = 1
param maxReplica int = 2

param sftpUser string = 'sftp'
@secure()
param sftpPassword string
param location string = resourceGroup().location

var sftpContainerName = 'sftp'
var sftpContainerImage = 'atmoz/sftp:latest'
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

resource acaVNet 'Microsoft.Network/virtualNetworks@2022-09-01' = {
  name: vNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: acaSubnetName
        properties: {
          addressPrefix: acaSubnetPrefix
        }
      }
    ]
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
    vnetConfiguration: {
      infrastructureSubnetId: acaVNet.properties.subnets[0].id
      internal: false
    }
  }
}

resource containerAppEnvSftpStorage 'Microsoft.App/managedEnvironments/storages@2022-10-01' = {
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

resource containerApp 'Microsoft.App/containerApps@2022-10-01' = {
  name: containerAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      secrets: [
        {
          name: 'sftpenvvariable'
          value: sftpEnvVariable
        }
      ]
      ingress: {
        external: true
        targetPort: 22
        exposedPort: 22
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
        transport: 'tcp'
      }
    }
    template: {
      revisionSuffix: 'firstrevision'
      containers: [
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
            cpu: json('0.5')
            memory: '1Gi'
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
