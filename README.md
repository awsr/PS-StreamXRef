# Get-TwitchXRef

Have you ever seen a clip from several people streaming together and wanted to see what it looked like from other perspectives?

---

You will need to have a valid ClientID, which you can obtain from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

* For PowerShell 7.0+, use `Import-Module Get-TwitchXRef.psd1`

* For earlier versions of PowerShell, run `Legacy/Setup-TwitchXRef-BackCompat.ps1` to load the function into the current PowerShell session.

---

Alias: `gtxr`

`Get-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-ClientID <String>] [-PassThru]`

**-Source** accepts Twitch clips in either URL format, Twitch clip IDs, and video URLs that include a timestamp parameter.

**-XRef** accepts either a video URL, a channel URL, or a channel/user name.

**-Count** (*default 10*) determines the number of videos to request when **-XRef** is a name.

**-ClientID** (*required 1st time in session*) accepts your Twitch client ID.

**-PassThru** returns the URL as a string instead of writing to host.
