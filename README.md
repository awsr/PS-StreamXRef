# StreamXRef

Have you ever seen a clip from several people streaming together and wanted to see what it looked like from other perspectives?

---

You will need to have a valid API key (Client ID), which you can obtain from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

---

## Find-TwitchXRef

Alias: `txr`

```
Find-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-Offset <Int32>] [-Force]
 -ApiKey <String> [<CommonParameters>]
```

**-Source** accepts Twitch clip URLs (either format), Twitch clip IDs, and video URLs that include a timestamp parameter.

**-XRef** accepts either a video URL, a channel URL, or a channel/user name.

**-Count** (*default 20*) determines the number of videos to request when **-XRef** is a name.

**-Offset** (*default 0*) sets the starting offset for search results when **-XRef** is a name.

**-Force** tells the cmdlet to skip reading from the internal lookup cache.

**-ApiKey** (*required 1st time in session if not set*) accepts your API key (for Twitch this is the "Client ID").
