param storageAccountPrefix string
param storageAccountType string = 'Standard_LRS'
param sftpFileShareName string = 'sftpfileshare'
param sshKeyFileShareName string = 'sskkeyvolume'
param sftpUser string = 'sftp'

var sftpContainerName = 'sftp'
var sftpContainerGroupName = 'sftp-group'
var sftpContainerImage = 'atmoz/sftp:latest'
var sftpEnvVariable = '${sftpUser}::1001'
var storageAccountName = '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'
var location = resourceGroup().location

resource stgacct 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku:{
    name: storageAccountType
  }
}

resource sftpfileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: toLower('${stgacct.name}/default/${sftpFileShareName}')
}

resource sshfileshare 'Microsoft.Storage/storageAccounts/fileServices/shares@2019-06-01' = {
  name: toLower('${stgacct.name}/default/${sshKeyFileShareName}')
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
            {
              mountPath: '/home/${sftpUser}/.ssh/keys'
              name: 'sshkeyvolume'
              readOnly: true
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
          shareName: sftpFileShareName
          storageAccountName: stgacct.name
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
      {
        name: 'sshkeyvolume'
        azureFile:{
          readOnly: true
          shareName: sshKeyFileShareName
          storageAccountName: stgacct.name
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
    ]
  }
}

output containerIP string = containergroup.properties.ipAddress.ip