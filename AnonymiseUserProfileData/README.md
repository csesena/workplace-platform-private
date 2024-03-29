# Anonymise user profile data on Workplace after deactivation on MS Azure AD

**Language:** Powershell 7

## Disclaimer
Use at your own risk. Once the script is run, the profile data of the users that have been deactivated may be overwritten with new values and the script doesn't have a mechanism to undo the changes.

## Description
This PowerShell script allows to anonymise the profile data of a user on Workplace when their account has been deactivated on MS Azure AD more than N days ago.

## Setup

* Create a new Custom Integration in the Workplace Admin Panel: [Create a custom Integration](https://developers.facebook.com/docs/workplace/custom-integrations-new/#creating).<br/>This requires at least "Manage accounts" permission. Take note of the Access Token.

* Create a new app registration on [Azure](https://docs.microsoft.com/en-us/azure/active-directory/develop/quickstart-register-app) with at least User.Read.All permissions.

* Create a file named `accessToken.js` with the following content:

   ```javascript
   {
         'accessToken' : 'YOUR-ACCESS-TOKEN',
         'tenant' : 'YOUR-AZURE-TENANT-ID',
         'client_id' : 'YOUR-REGISTERED-APP-ID',
         'client_secret' : 'YOUR-REGISTERED-APP-SECRET',
         'anonymisation_threshold_in_days' : 90,
         'anonymisation_lower_threshold_in_days' : 180
   }
   ```
* Here you have the the details of the parameters to be used in the `accessToken.js` file:

   | Parameter            | Description                                                       |  Type    |  Required    |
   |:--------------------:|:-----------------------------------------------------------------:|:--------:|:------------:|
   | accessToken        |  The WP Access Token that you retrieved after creating your Custom Integration                 | _String_ | Yes          |
   | tenant        |  Azure Tenant ID                 | _String_ | Yes          |
   | client_id        |  Your registered app ID from Azure                | _String_ | Yes          |
   | client_secret        |  Your registered app Secret from Azure                | _String_ | Yes          |
   | anonymisation_threshold_in_days   |  Users whose deletion date on AD is LOWER than the date of today minus this value will be anonymised                        | _int_ | Yes          |
   | anonymisation_lower_threshold_in_days   |  Users whose deletion date on AD is GREATER than the date of today minus this value will be anonymised                        | _int_ | Yes          |



## Run

* Run the script by passing the `accessToken.js` file as input:

   ```powershell
   ./anonymiseUsers.ps1 -WPAccessToken accessToken.js
   ```

## Parameters
Here you have the the details of the parameters to be used:

   | Parameter            | Description                                                       |  Type    |  Required    |
   |:--------------------:|:-----------------------------------------------------------------:|:--------:|:------------:|
   | WPAccessToken        |  The path for the JSON file with the access token                 | _String_ | Yes          |
