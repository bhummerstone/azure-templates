param vnet_prefix string = 'bhvnet'

var vnet_configuration = [
  {
    addressPrefix: '10.0.0.0/22'
    subnets: [
      {
        name: 'firstSubnet'
        addressPrefix: '10.0.0.0/24'
      }
      {
        name: 'secondSubnet'
        addressPrefix: '10.0.1.0/24'
      }
    ]
  }
  {
    addressPrefix: '10.1.0.0/22'
    subnets: [
      {
        name: 'firstSubnet'
        addressPrefix: '10.1.1.0/24'
      }
      {
        name: 'secondSubnet'
        addressPrefix: '10.1.2.0/24'
      }
    ]
  }
]

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = [for (config, i) in vnet_configuration: {
  name: '${vnet_prefix}${i}'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        config.addressPrefix
      ]
    }
    subnets: [for subnet in config.subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}]
