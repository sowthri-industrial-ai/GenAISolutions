using './main.bicep'

param location = 'eastus2'
param env = 'dev'
param ownerTag = readEnvironmentVariable('OWNER_TAG', 'unset')
param resourceGroupName = 'rg-procurement-dev-eastus2'
