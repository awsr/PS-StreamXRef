# Get-TwitchXRef

Have you ever seen a clip from several people streaming together and wanted to see what it looked like from other perspectives?

---

You will need to have a valid ClientID, which you can obtain from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

---

Alias: `gtxr`

`Get-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-ClientID <String>] [-PassThru]`

**-Source** accepts Twitch clips in either URL format, Twitch clip IDs, and video URLs that include a timestamp parameter.

**-XRef** accepts either a video URL, a channel URL, or a channel/user name.

**-ClientID** (*required 1st time in session*) accepts your Twitch client ID.

**-Count** (*default 10*) determines the number of videos to request when **-XRef** is a name.

**-Offset** (*default 0*) sets the starting offset for search results when **-XRef** is a name.
