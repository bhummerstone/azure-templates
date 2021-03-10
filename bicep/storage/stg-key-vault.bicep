var kvname = 'bhstgkv'
var secretname = 'stgacctname'

resource kv 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: kvname
}

module stgacct 'stg-acct.bicep' = {
  name: 'stgDeploy'
  params: {
    storageAccountName: {
      reference: {
        keyVault: {
          id: kv.id
        }
        secretName: secretname
      }
    }
    location: resourceGroup().location
    storageAccountType: 'StandardV2'
  }
}