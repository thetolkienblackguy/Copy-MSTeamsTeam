# Copy-MSTeamsTeam
While Microsoft provides avenues to easily clone a Team whether using the Teams client or Graph API's clone url.  The cloning isn't as robust 
as it could be, both avenues miss key components that an administrator may want to clone, like but not limited to private channels. 
This script not only copies the group's public channels, but its private channels, and private channel members including their correct roles. 
It's also been my experience while the Teams client will copy guest Teams members, using clone  
https://graph.microsoft.com/v1.0/teams/{TeamId{/clone) from the Graph API doesn't. This script, however, will.

As you read through the script you may wonder why I use Invoke-WebRequest as opposed to Invoke-RestMethod for my API calls. This was simply 
a mistake that I caught after all the functions were completed.  I plan to correct in a future version.  



## Dependencies


```powershell
#Requires -Version 3.0
```
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

## Usage
I tend to use the default parameters of my scripts like most people use variables. You will have to define them for your tenant.
Nonetheless, the parameters can be called interactively when executing the script.  

```powershell


#This will create a team called "A cloned team" and copy all settings, members, tabs, and channels from the source team. The ObjectId parameter defines the source. 
.\Copy-MSTeamsTeam -ObjectId SomeObjectId -NewTeam "A cloned Team" -NewMailNickName "clonedTeam" -ClientID SomeAppID -TenantId YourTenantIDHere -ClientSecret SomeClientSecret


```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.


## License
[MIT](https://choosealicense.com/licenses/mit/)

## Contact
I'm an IT Consultant for the Federal Government and small businesses that specializes in M365, AD, and process automation. If you feel I can help you with a project please don't hesitate to reach out [PowerShellDev@PhzConsulting.com](PowerShellDev@PhzConsulting.com).  I'm always looking for new clients and challenges
