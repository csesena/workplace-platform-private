param(
    [Parameter(Mandatory=$true, Position=0, HelpMessage='Path for your Workplace access token in .json format {"accessToken" : 123xyz}')] [string]$WPAccessToken
)

function GetAccessTokenCredentials
{
    #Read JSON Access Token
    try
    {
        $global:token = (Get-Content $WPAccessToken | Out-String | ConvertFrom-Json -ErrorAction Stop).accessToken
		$global:tenant = (Get-Content $WPAccessToken | Out-String | ConvertFrom-Json -ErrorAction Stop).tenant
		$global:clientid = (Get-Content $WPAccessToken | Out-String | ConvertFrom-Json -ErrorAction Stop).client_id
		$global:clientsecret = (Get-Content $WPAccessToken | Out-String | ConvertFrom-Json -ErrorAction Stop).client_secret
		$global:anonymthreshold = (Get-Content $WPAccessToken | Out-String | ConvertFrom-Json -ErrorAction Stop).anonymisation_threshold_in_days
        Write-Host -NoNewLine "Access Token Credentials - JSON File: "
        Write-Host -ForegroundColor Green "OK, Read!"
    }
    catch
    {
        #Handle exception when passed file is not JSON
        Write-Host -ForegroundColor Red "Fatal Error when reading JSON file. Is it correctly formatted?"
        exit;
    }

}

function AnonymiseWorkplaceUserProfile
{
    param (
        $userId
    )

    #Anonymise User Data
    Write-Host -NoNewLine "Anonymising user $userId profile data on Workplace... "
    try
    {
		$todayDate = Get-Date -Format "yyyyMMdd"
		$userDataUrl = "https://www.workplace.com/scim/v1/Users/$userId"

        #Requesting data of the user to Workplace
        $results = Invoke-RestMethod -Uri ($userDataUrl) -Headers @{ Authorization = "Bearer " + $global:token } -UserAgent "GithubRep-ProfileAnonymiser"

		if ($results -and !$results.error)
        {
			#Formatting data to be sent for the anonymisation
			$emailParts = $results.userName.Split("@")
			if ($results.externalId) {
				$newUsername = $results.externalId + "_" + $todayDate + "@" + $emailParts[1]
			} else {
				$randomString = -join ((65..90) + (97..122) | Get-Random -Count 10 | % {[char]$_})
				$newUsername = $randomString + "_" + $todayDate + "@" + $emailParts[1]
			}

			$requestBody = '{
				"schemas" : ["urn:scim:schemas:core:1.0", "urn:scim:schemas:extension:enterprise:1.0", "urn:scim:schemas:extension:facebook:starttermdates:1.0"],
				"userName" : "' + $newUsername + '",
				"displayName" : "Default User",
				"name" : {
					"formatted" : "Default User",
					"familyName" : "User",
					"givenName" : "Default"
				},
				"active" : ' + $results.active.ToString().ToLower() + ',
				"title" : "Default Title",
				"emails" : [{
					"primary" : false,
					"value" : "' + $newUsername + '"
				}],
				"urn:scim:schemas:extension:enterprise:1.0" : {
					"organization" : "Default Org",
					"division" : "Default Region",
					"department" : "Default Department"
				},
				"locale": "en_US",
				"preferredLanguage": "en_US",
				"addresses": [{
					"type": "work",
					"formatted": "Default Office",
					"primary": true
				}],
				"urn:scim:schemas:extension:facebook:starttermdates:1.0": {
					"startDate": 1577836800
				},
				"phoneNumbers": [{
					"primary": true,
					"type": "work",
					"value": "+1-202-555-0104"
				}],
				"photos": [{
					"value" : "https://static.xx.fbcdn.net/rsrc.php/v1/yN/r/5YNclLbSCQL.jpg",
					"type" : "profile",
					"primary" : true
				}]
			}';
			#Write-Host $requestBody
            $resultsModification = Invoke-RestMethod -Method PUT -URI ($userDataUrl) -Headers @{Authorization = "Bearer " + $global:token} -Body $requestBody -ContentType "application/json" -UserAgent "GithubRep-ProfileAnonymiser"
        }

		if ($resultsModification -and !$resultsModification.error)
        {
			Write-Host -ForegroundColor Green "Profile data from user $userId has been successfully anonymised. New data:"
			Write-Host -ForegroundColor Green $resultsModification
			return $true
		} else {
			Write-Host -ForegroundColor Red "Fatal API Error when modifying user profile data."
			Write-Host -ForegroundColor Red $resultsModification.error
			return $false
		}

    }
    catch
    {
        #Handle exception when having errors from SCIM API
        Write-Host -ForegroundColor Red "Fatal Error when anonymising user profile data via API."
        Write-Host -ForegroundColor Red $_
		return $false
    }

}

function AuthenticateMSGraphAPI
{
	try
	{
		# Create a hashtable for the body, the data needed for the token request
		# The variables used are explained above
		$Body = @{
			'tenant' = $global:tenant
			'client_id' = $global:clientid
			'scope' = 'https://graph.microsoft.com/.default'
			'client_secret' = $global:clientsecret
			'grant_type' = 'client_credentials'
		}

		# Assemble a hashtable for splatting parameters, for readability
		# The tenant id is used in the uri of the request as well as the body
		$Params = @{
			'Uri' = "https://login.microsoftonline.com/$global:tenant/oauth2/v2.0/token"
			'Method' = 'Post'
			'Body' = $Body
			'ContentType' = 'application/x-www-form-urlencoded'
		}

		$AuthResponse = Invoke-RestMethod @Params

		# Return MS Access Token
		return $AuthResponse.access_token
	}
	catch
	{
		#Handle exception when having errors from MS Graph API
        Write-Host -ForegroundColor Red "Fatal Error when authenticating to retrieve user profile from MS Graph API."
        Write-Host -ForegroundColor Red $_
	}
}

function RetrieveUserDataFromMS
{
	param (
        $MSAuthToken
    )

	try
	{
		#Write-Host $MSAuthToken
		$Headers = @{
			'Authorization' = "Bearer $($MSAuthToken)"
		}

		$Result = Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.user?$select=id,displayName,givenName,userPrincipalName,accountEnabled,createdDateTime,deletedDateTime,externalUserStateChangeDateTime
' -Headers $Headers

		#Write-Host $Result

		return $Result.value
	}
	catch
	{
		#Handle exception when having errors from MS Graph API
        Write-Host -ForegroundColor Red "Fatal Error when retrieving deleted user data from MS Graph API."
        Write-Host -ForegroundColor Red $_
	}
}

function AssessAnonymisation
{
	param (
        $DeletedUsers
    )

	try
	{
		$TodayDate = Get-Date
		$TodayMinusThreshold = $TodayDate.AddDays([int]$global:anonymthreshold * -1)
		Write-Host "Anonymising deleted users that were deleted on AD before " $TodayMinusThreshold

		$AnonymisedUsersCount = 0

		#Write-Host $DeletedUsers
		$DeletedUsers | ForEach-Object -Process {

			$deletionDate = [datetime]::ParseExact($_.deletedDateTime,'MM/dd/yyyy HH:mm:ss', $null)
			if ($deletionDate -lt $TodayMinusThreshold) {

				$userDataUrl = "https://www.workplace.com/scim/v1/Users/?filter=externalId%20eq%20%22" + $_.id + "%22"

				#Requesting data of the user to Workplace
				$results = Invoke-RestMethod -Uri ($userDataUrl) -Headers @{ Authorization = "Bearer " + $global:token } -UserAgent "GithubRep-ProfileAnonymiser"
				#Write-Host $results.Resources.id

				if (AnonymiseWorkplaceUserProfile -userId $results.id)
				{
					$AnonymisedUsersCount++
				}
			}
		}

		Write-Host -ForegroundColor Green "$AnonymisedUsersCount users have been anonymised. Process completed."
	}
	catch
	{
		#Handle exception when having errors from MS Graph API
        Write-Host -ForegroundColor Red "Fatal Error assessing if user should be deleted."
        Write-Host -ForegroundColor Red $_
	}
}

GetAccessTokenCredentials
$MSAuthorizationToken = AuthenticateMSGraphAPI
$DeletedUsers = RetrieveUserDataFromMS -MSAuthToken $MSAuthorizationToken
AssessAnonymisation -DeletedUsers $DeletedUsers
