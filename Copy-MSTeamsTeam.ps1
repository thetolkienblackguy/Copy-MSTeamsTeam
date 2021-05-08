<###########################################################################################################################################
.DESCRIPTION 
While Microsoft provides avenues to easily clone a Team whether using the Teams client or Graph API's clone url.  The cloning isn't as robust 
as it could be, both avenues miss key components that an administrator may want to clone, like but not limited to private channels.
This script not only copies the group's public channels, but its private channels, and private channel members including their correct roles. 
It's also been my experience while the Teams client will copy guest Teams members, using clone 
(https://graph.microsoft.com/v1.0/teams/{TeamId{/clone) from the Graph API doesn't. This script, however, will.

As you read through the script you may wonder why I use Invoke-WebRequest as opposed to Invoke-RestMethod for my API calls. This was simply 
a mistake that I caught after all the functions were completed.  I plan to correct in a future version.  

.EXAMPLE
I tend to use the default parameters of my scripts like most people use variables. You will have to define them for your tenant
Nonetheless, the parameters can be called interactively when executing the script.  
.\Copy-MSTeamsTeam -ObjectId SomeObjectId -NewTeam "A cloned Team" -NewMailNickName "clonedTeam" -ClientID SomeAppID 
    -TenantId YourTenantIDHere -ClientSecret SomeClientSecret


.NOTES
Author: Gabe Delaney 
Email: PowerShellDev@phzconsulting.com
Version: 1.0
Date: 05/07/2021
Name: Copy-MSTeamsTeam

Version History:
1.0 - Original Release - https://github.com/thetolkienblackguy
The script requires an App Registration with the following Microsoft Graph (Application) permissions:
Channel.Create
ChannelMember.Read.All
ChannelMember.ReadWrite.All
Directory.ReadWrite.All
Group.ReadWrite.All
TeamMember.Read.All
TeamMember.ReadWrite.All
TeamMember.ReadWriteNonOwnerRole.All
User.Invite.All
###########################################################################################################################################>
#Requires -Version 3.0
param (        
    <#
        These default parameters need to be updated.  All except LogFile are placeholders. 
    
    #>
    [Parameter(Mandatory=$false)] 
    [string]$ObjectId = "<REDACTED>",
    [Parameter(Mandatory=$false)] 
    [string]$NewTeam = "A Cloned Team",
    [Parameter(Mandatory=$false)] 
    [string]$NewMailNickName = "aclonedteam",
    [Parameter(Mandatory=$false)] 
    [string]$ClientId = "<REDACTED>",
    [Parameter(Mandatory=$false)] 
    [string]$ClientSecret = "<REDACTED>",
    [Parameter(Mandatory=$false)] 
    [string]$TenantId = "<REDACTED>",
    [Parameter(Mandatory=$false)] 
    [string]$LogFile = ".\Copy-MSTeamsTeam_$(Get-Date -Format MMddyyyy_hhmmss).log"

)
Function Invoke-Logging {
    <#
        This function just helps streamline logging.  Specifically when logging to a file AND the console.
    
    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$true)]
        [string]$LogFile,
        [Parameter(Mandatory=$false)]
        [switch]$WriteOutput,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "Black",
            "Blue",
            "Cyan",
            "DarkBlue",
            "DarkCyan",
            "DarkGray",
            "DarkGreen",
            "DarkMagenta",
            "DarkRed",
            "DarkYellow",
            "Gray",
            "Green",
            "Magenta",
            "Red",
            "Yellow",
            "White"

        )]
        [string]$ForeGroundColor = "Yellow"

    )
    Begin {
        $message = "$("[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)) $message"
        $logPath = Split-Path $logFile -Parent
        If (!(Test-Path $logPath)) {
            New-Item -Path $logPath -ItemType Directory -Force | Out-Null
        
        }
    }
    Process {
        $message | Out-File $logFile -Append

    } End {
        If ($writeOutput) {
            Write-Host $message -ForegroundColor $foreGroundColor -BackgroundColor Black

        }
    }
}
Function New-oAuthToken {
    <#
        This function requests an oAuth token from the Graph or Office API
    
    #>
    [CmdletBinding()]
    param ( 
        [Parameter(Mandatory=$true)] 
        [string]$ClientId,
        [Parameter(Mandatory=$true)] 
        [string]$ClientSecret,
        [Parameter(Mandatory=$true)] 
        [string]$TenantId,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "https://manage.office.com",
            "https://graph.microsoft.com"

        )]
        [string]$Resource = "https://graph.microsoft.com"

    )
    Begin {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $loginURL = "https://login.microsoft.com"
        #Creates credential hashtable
        $tokenRequestBody = @{
            grant_type = "client_credentials"
            resource = $resource
            client_id = $clientId
            client_secret = $clientSecret
        
        }        
    } Process {
        #Creates oAuth token
        $oAuth = Invoke-RestMethod -Method Post -Uri "$loginURL/$tenantId/oauth2/token?api-version=1.0" -Body $tokenRequestBody -UseBasicParsing

    }
    End {
        Return $oAuth

    }
}
Function Get-MSTeamsChannel {
    <#
        This function retrieves information about a channel in a Team.  If no channel is specified all channels
        are returned. 
    
    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$false)]
        [string]$ChannelId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken,
        [Parameter(Mandatory=$false)]
        [boolean]$PrivateOnly = $false 

    )
    Begin {
        $baseUri = "https://graph.microsoft.com/v1.0/teams/$objectId/channels"
        If ($channelId) {
            #Specifying a chennal will cancel out $privateOnly
            $privateOnly = $false
            $uri = $baseUri + "/$channelId"
        
        } Else {
            If ($privateOnly) {
                $uri = $baseUri + "?`$filter=membershipType eq 'private'"    

            } Else {
                $uri = $baseUri

            }
        }
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "appplication/json" 

            }
            Uri = $uri
            Method = "Get"   
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams 
        If ($channelId) {
            $channelObj = $response.content | ConvertFrom-Json

        } Else {
            $channelObj = ($response.content | ConvertFrom-Json).value
        
        }
    } End {
        Return $channelObj 
    }
}
Function Get-MSTeamsChannelMember {
    <#
        This function retrieves members of a channel, while it doesn't really provide much value for a Public channel
        it is specifically designed for Private channels. 
    
    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$ChannelId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken
    
    )
    Begin {
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "appplication/json" 

            }
            Uri = "https://graph.microsoft.com/v1.0/teams/$objectId/channels/$channelId/members"
            Method = "Get"   
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams 
        $memberObj = ($response.content | ConvertFrom-Json).value

    } End {
        Return $memberObj  
    }
}
Function Get-MSTeamsTeamMember {
    <#
        This function retrieves all members of a team and their roles

    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken,
        [Parameter(Mandatory=$false)]
        [boolean]$GuestsOnly
       
    )
    Begin {
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "appplication/json" 

            }
            Uri = "https://graph.microsoft.com/v1.0/teams/$objectId/members"
            Method = "Get"   
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams 
        If ($guestsOnly) {
            #Would rather do this during the API call but can't get the logic to work as I expect it to.  Will come back to this in the future. 
            $memberObj = ($response.content | ConvertFrom-Json).value | Where-Object {$_.roles -eq "guest"}
        
        } Else {
            $memberObj = ($response.content | ConvertFrom-Json).value
        
        }
    } End {
        Return $memberObj  
    }
}
Function Add-MSTeamsTeamMember {
    <#
        This function adds users to a Team and assigns roles. 

    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "Guest",
            "Owner"

        )]
        [Collections.Generic.List[String]]$Roles
    
    )
    Begin {
        If ($roles -ne "Guest") {
            <#
                This part of the code annoys me and I feel like I'm missing something.  But I wasn't able to add a Guest
                to the Team using the Graph API documentation for adding a Teams member.  However, since all teams are
                M365\Unified groups I was able to leverage groups uri to add Guest accounts.  Thus the reason for conditional
                logic and different payloads. 
            
            #>
            $body = [pscustomobject] [ordered] @{
                "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                roles = @($roles) 
                "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$userId')" 

            } | ConvertTo-Json
            $uri = "https://graph.microsoft.com/v1.0/teams/$objectId/members"
        } Else {
            $body = [pscustomobject] [ordered] @{
                "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$userId"
    
            } | ConvertTo-Json
            $uri = "https://graph.microsoft.com/v1.0/groups/$objectId/members/`$ref"
        }
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "application/json" 

            }
            Uri = $uri
            Method = "Post"
            Body = $body 
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams 

    } End {
        Return $response  
        
    }
}
Function Add-MSTeamsChannelMember {
    <#
        This is a vital function for Private channels.  This allows assignment of users to Private channels
        with specific roles.  

    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$UserId,
        [Parameter(Mandatory=$true)]
        [string]$ChannelId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "Owner",
            "Guest",
            #null is simply a member
            $null

        )]
        [Collections.Generic.List[String]]$roles = $null
    
        )
    Begin {
        $body = [pscustomobject] [ordered] @{
            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
            roles = $roles 
            "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$userId')" 

        } | ConvertTo-Json
        $uri = "https://graph.microsoft.com/v1.0/teams/$objectId/channels/$channelId/members"
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "application/json" 

            }
            Uri = $uri
            Method = "Post"
            Body = $body 
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams 

    } End {
        Return $response  
        
    }
}
Function New-MSTeamsChannel {
    <#
        This function creates a Teams channel. As the script description points out,  Private channels are not cloned to or
        used by a template when creating a new channel. 

    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("Id")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$DisplayName,
        [Parameter(Mandatory=$false)]
        [string]$Description,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "Private",
            "Standard"

        )]
        [string]$MembershipType = "Private",
        [Parameter(Mandatory=$false)]
        [string]$OwnerId,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken
    
    )
    Begin {
        If ($membershipType -eq "Standard") {
            $body = [pscustomobject] [ordered] @{
                displayName = $displayName
                description = $description
                membershipType = $membershipType

            } | ConvertTo-Json
        } Else {
            $body = [pscustomobject] [ordered] @{
                "@odata.type" = "#Microsoft.Graph.channel"
                membershipType = $membershipType
                displayName = $displayName
                description = $description
                members = @(
                    [pscustomobject] [ordered] @{
                        "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                        "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$ownerId')" 
                        roles = @("Owner")
                    }
                )
            } | ConvertTo-Json -Depth 3
        }
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "application/json" 

            }
            Uri = "https://graph.microsoft.com/v1.0/teams/$objectId/channels"
            Method = "Post"
            Body = $body 
        
        }
    } Process {
        $response = Invoke-WebRequest @invokeWebRequestParams
        $channelObj = $response.content | ConvertFrom-Json

    } End {
        Return $channelObj  
        
    }
}
Function Invoke-MSTeamsClone {
    <#
        This function creates a baseline clone of a team and is the impetus for the entirety of the rest of the script. 
        After testing this I felt that there were definitely use cases where one would want to also clone Private channels
    
    #>
    [CmdletBinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [alias("SourceId","SourceObjectId")]
        [string]$ObjectId,
        [Parameter(Mandatory=$true)]
        [string]$NewTeam,
        [Parameter(Mandatory=$false)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$MailNickName,
        [Parameter(Mandatory=$true)]
        [string]$AccessToken,
        [Parameter(Mandatory=$false)]
        [ValidateSet(
            "Public",
            "Private"

        )]
        [string]$Visibility = "Private",
        [Parameter(Mandatory=$false)]
        <#
            It's been my experience that the GraphAPI does a great job of copying in-tenant members, settings, and tabs. Apps and guests not so much. 
            While I include apps here I've found no evidence it actually works as the documentation says it will. 
        
        #>
        [array]$PartsToClone = @(
            "apps","channels","members","settings","tabs"
        
        ) 
    )
    Begin {
        $body = [pscustomobject] [ordered] @{
            displayName = $newTeam 
            description = $description
            mailNickName = $MailNickName
            partsToClone = $PartsToClone -join ","
            visibility = $Visibility
        
        } | ConvertTo-Json
        $invokeWebRequestParams = @{
            Headers = @{
                Authorization = "Bearer $accessToken"
                "content-type" = "appplication/json" 

            }
            Uri = "https://graph.microsoft.com/v1.0/teams/$objectId/clone"
            Method = "Post"
            Body = $body    
        
        }
    } Process { 
        $response = Invoke-WebRequest @invokeWebRequestParams
        
    } End {
        Return $response

    }
}
#Invoke-Logging base parameters
$invokeLoggingParams = @{
    LogFile = $logFile
    WriteOutput = $true 

}
#New-oAuthToken parameters
$newoAuthParams = @{
    ClientId = $clientId
    ClientSecret = $clientSecret
    TenantID = $tenantId

}
Invoke-Logging -Message "Starting Copy-MSTeamsTeam" @invokeLoggingParams -ForeGroundColor Cyan
Invoke-Logging -Message "Requesting access token" @invokeLoggingParams
Try {
    $accessToken = (New-oAuthToken @newoAuthParams).access_token
    Invoke-Logging -Message "Token issued successfully" @invokeLoggingParams -ForeGroundColor Green

} Catch {
    Invoke-Logging -Message "Unable to obtain access token $($error[0].Exception.Message)" @invokeLoggingParams -ForeGroundColor Red
    Exit

}
Invoke-Logging -Message "Starting initial copy of settings, members, and public channels" @invokeLoggingParams
Try {
    #This is the initial clone of the source team.  Which will pull in Teams specific settings, tabs, and in-tenant members. 
    $cloneResponse = Invoke-MSTeamsClone -ObjectId $objectId -NewTeam $newTeam -MailNickName $newMailNickName -AccessToken $accessToken 
    Invoke-Logging -Message "Initial copy has completed successfully" @invokeLoggingParams -ForeGroundColor Green

} Catch {
    Invoke-Logging -Message "Failed to clone $objectId $($error[0].Exception.Message)" @invokeLoggingParams -ForeGroundColor Red
    Exit

}
#Base parameters for all Get-MSTeams functions
$getGraphParams = @{
    Id = $objectId
    AccessToken = $accessToken

}
#Base parameters for all New\Add-MSTeams functions
$addGraphParams = @{
    Id = ""
    AccessToken = $accessToken

}
$newTeamId = ($cloneResponse.headers."Content-Location" -split "'")[1]
$addGraphParams.Id = $newTeamId
Invoke-Logging -Message "Allowing time for new group to replicate through Azure AD" @invokeLoggingParams
Start-Sleep -Seconds 30
Try {
    #Retrieving Teams channels and members.  The goal is to account for private channels and special roles. 
    $channels = Get-MSTeamsChannel @getGraphParams | Select-Object id,displayName,membershipType
    $teamsMembers = Get-MSTeamsTeamMember @getGraphParams | Select-Object userId,displayName,roles 

} Catch {
    Invoke-Logging -Message "Unable to retrieve information from $objectId. Exiting"
    Exit 

}    
<#
    Team cloning doesn't clone guests and - at least in my testing - doesn't regrant Ownership of the team 
    (I'm open to being corrected here).  This iterates through each user and assigns ownership or adds guests
    that were part of the source team 

#>
Foreach ($teamsMember in $teamsMembers) {
    $role = $teamsMember.roles
    If ($role -eq "Owner" -or $role -eq "Guest") {
        $displayName = $teamsMember.displayName
        $memberId = $teamsMember.userId
        Invoke-Logging -Message "Adding role $role to $displayName" @invokeLoggingParams
        Try {
            Add-MSTeamsTeamMember @addGraphParams -UserId $memberId -Roles $role | Out-Null
            Invoke-Logging -Message "$displayName updated successfully" @invokeLoggingParams -ForegroundColor Green
            Start-Sleep -Seconds 2
        
        } Catch {
            Invoke-Logging -Message "Adding role $role to $displayName failed" @invokeLoggingParams

        }
    } Else {
        Continue

    }
} 
<#
    Copying Private channels from the source team to the new team.  Then reassigning rights to each Private
    channel to mirror the source channels' rights distribution. 

#>
foreach ($channel in $channels) {
    $membershiptype = $channel.membershipType
    If ($membershipType -eq "Private") {
        $id = $channel.id
        $displayName = $channel.displayName
        Try {
            Invoke-Logging "Getting members of channel $displayName" @invokeLoggingParams
            $channelMembers = Get-MSTeamsChannelMember @getGraphParams -ChannelId $id | Select-Object userId,displayName,roles 
            #When creating a private team it needs to be created on behalf of a user. 
            $ownerId = ($channelMembers | Where-Object {$_.roles -eq "Owner"})[0].userID
            Invoke-Logging -Message "Copying channel $displayName to $newTeam" @invokeLoggingParams
            $newChannel = (New-MSTeamsChannel @addGraphParams -DisplayName $displayName -OwnerId $ownerId).id
            Start-Sleep -Seconds 2
            Invoke-Logging -Message "Channel $displayName has been copied to $newTeam successfully" @invokeLoggingParams -ForegroundColor Green

        } Catch {
            Invoke-Logging -Message "Failed to copy channel $displayName to $newTeam. $($error[0].Exception.Message)" @invokeLoggingParams

        }
        Foreach ($channelMember in $channelMembers) {
            $userId = $channelMember.userId
            $channelRole = $channelMember.roles
            $userDisplayName = $channelMember.displayName
            Try {                
                Invoke-Logging -Message "Adding $userDisplayName to $displayName" @invokeLoggingParams
                Add-MSTeamsChannelMember @addGraphParams -ChannelId $newChannel -UserId $userId -Roles $channelRole | Out-Null 
                Invoke-Logging -Message "$userDisplayName was successfully added to $displayName" @invokeLoggingParams -ForegroundColor Green
                Start-Sleep -Seconds 2
            
            } Catch {
                Invoke-Logging -Message "Unable to add $userDisplayName to $displayName. $($error[0].Exception.Message)" @invokeLoggingParams -ForeGroundColor Red

            }        
        }   
    } Else {
        Continue

    }
}
Invoke-Logging -Message "$newTeam has been created successfully.  Please allow time for the all changes to reflect in the Teams client.  Try signing out and back in if all changes aren't visible after 15 minutes" @invokeLoggingParams -ForeGroundColor Cyan