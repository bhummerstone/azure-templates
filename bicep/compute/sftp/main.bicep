param storageAccountPrefix string
param storageAccountType string = 'Standard_LRS'
param fileShareName string = 'sftpfileshare'
param sftpUser string = 'sftp'
param sftpPassword string {
  secure: true
}

var sftpContainerName = 'sftp'
var sftpContainerGroupName = 'sftp-group'
var sftpContainerImage = 'atmoz/sftp:latest'
var sftpEnvVariable = '${sftpUser}:${sftpPassword}:1001'
var storageAccountName = '${storageAccountPrefix}uniquniqueString(resourceGroup().id)'
var location = resourceGroup().location

resource stgacct 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku:{
    name: storageAccountType
  }
}

resource fileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: '${stgacct.name}/default/${fileShareName}'
}

resource containergroup 'Microsoft.ContainerInstance/containerGroups@2019-12-01' = {
  name: sftpContainerGroupName
  location: location
  properties: {
    containers: [
      {
        name: sftpContainerName
        properties: {
          image: sftpContainerImage
          environmentVariables: [
            {
              name: 'SFTP_USERS'
              secureValue: sftpEnvVariable
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          ports:[
            {
              port: 22
              protocol: 'TCP'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/home/${sftpUser}/upload'
              name: 'sftpvolume'
              readOnly: false
            }
          ]
        }
      }
    ]

    osType:'Linux'
    ipAddress: {
      type: 'Public'
      ports:[
        {
          port: 22
          protocol:'TCP'
        }
      ]
    }
    restartPolicy: 'OnFailure'
    volumes: [
      {
        name: 'sftpvolume'
        azureFile:{
          readOnly: false
          shareName: fileshare.name
          storageAccountName: stgacct.name
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
    ]
  }
}

output containerIP string = containergroup.properties.ipAddress.ip