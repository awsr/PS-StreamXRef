# Get-TwitchXRef
Cross-reference events between streams. Tested using PowerShell 7.0.

Run the script to load the function into the current PowerShell session. 
You will need to have a valid ClientID, which you can obtain from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

**-Clip** accepts either URL format for Twitch clips.

**-VideoUri** accepts video URLs that include a timestamp parameter.

**-XRef** accepts either a video URL or a channel/user name.

**-Count** (*default 10*) determines the number of videos to request when **-XRef** is a name.

**-ClientID** (*required 1st time in session*) accepts your Twitch client ID.

**-PassThru** returns the URL as a string instead of writing to host.
