param sftpUser string = 'sftp'
param sftpPassword string {
  secure: true
}
param daprAPIToken string {
  secure: true
}
param daprStorageAccountName string = 'bhdapr'
param daprFileShareName string = 'dapr-components'

var sftpContainerName = 'sftp'
var sftpContainerGroupName = 'sftp-group'
var sftpContainerImage = 'atmoz/sftp:latest'

var watcherContainerName = 'watcher'
var watcherContainerImage = 'ubuntu:latest'

var daprContainerName = 'dapr'
var daprContainerImage = 'daprio/dapr:edge'

var sftpEnvVariable = '${sftpUser}:${sftpPassword}:1001'
var location = resourceGroup().location

resource stgacct 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: daprStorageAccountName
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
          ports: [
            {
              port: 22
              protocol: 'TCP'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/home/${sftpUser}/upload'
              name: 'shared'
            }
          ]
        }
      }
      {
        name: watcherContainerName
        properties: {
          image: watcherContainerImage
          command: [
            '/bin/bash'
            '-c'
            'apt-get update; apt-get install inotify-tools wget -y;wget https://gist.githubusercontent.com/bhummerstone/92420db52c499f2e4e7a131240354cc2/raw/940a8be2dd2d22192780cd340e9040c1623e3d50/watcher-dapr.sh; chmod +x  watcher-dapr.sh; ./watcher-dapr.sh'
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          volumeMounts: [
            {
              mountPath: '/mnt/watcher'
              name: 'shared'
            }
          ]
        }
      }
      {
        name: daprContainerName
        properties: {
          image: daprContainerImage
          environmentVariables: [
            {
              name: 'DAPR_API_TOKEN'
              secureValue: daprAPIToken
            }
          ]
          command: [
            './daprd --app-id storage-proxy --components-path /components'
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          ports: [
            {
              port: 50001
              protocol: 'TCP'
            }
          ]
          volumeMounts: [
            {
              mountPath: '/components'
              name: 'dapr-components'
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
        name: 'dapr-components'
        azureFile:{
          readOnly: false
          shareName: daprFileShareName
          storageAccountName: daprStorageAccountName
          storageAccountKey: listKeys(stgacct.id, '2019-06-01').keys[0].value
        }
      }
      {
        name: 'shared'
        emptyDir: {}
      }
    ]
  }
}

output containerIP string = containergroup.properties.ipAddress.ip