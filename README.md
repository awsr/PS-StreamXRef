<img align="right" src="https://raw.githubusercontent.com/awsr/PS-StreamXRef/master/sxr.png">

# StreamXRef for PowerShell

[![PowerShell Gallery Version (including pre-releases)](https://img.shields.io/powershellgallery/v/StreamXRef)](https://www.powershellgallery.com/packages/StreamXRef/)
<br/>

Have you ever seen a clip from several people streaming together and wanted to see what it looked like from other perspectives? Find the same moment in time based on either a Twitch clip or a Twitch video URL with time offset.

The following are all valid formats for sources:
- `https://clips.twitch.tv/OilyDignifiedHamburgerHoneyBadger`
- `https://www.twitch.tv/twitch/clip/OilyDignifiedHamburgerHoneyBadger`
- `OilyDignifiedHamburgerHoneyBadger`
- `https://www.twitch.tv/videos/92248237?t=0h0m2s`
- `v/92248237?t=2s`

---

You will need to have a valid API key (Client ID), which you can obtain from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

---

## Find-TwitchXRef

Alias: `txr`

```
Find-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-Offset <Int32>] [-Force]
 -ApiKey <String> [-ExplicitNull] [<CommonParameters>]
```

**-Source** accepts Twitch clips (as a URL or just the ID) and videos with timestamps (as a URL or shorthand "v/...").

**-XRef** accepts Twitch channels/users (as a URL or just the name) and videos (as a URL or shorthand "v/...").

**-Count** (*default 20*) determines the number of videos to request when **-XRef** is a channel/user.

**-Offset** (*default 0*) sets the starting offset for search results when **-XRef** is a channel/user.

**-Force** tells the function to skip reading from the internal lookup cache.

**-ApiKey** (*required 1st time in session if not set*) accepts your API key (for Twitch this is the "Client ID").

**-ExplicitNull** tells the function to explicitly return a value of `$null` when encountering a [specified error](https://github.com/awsr/PS-StreamXRef/blob/master/docs/Find-TwitchXRef.md#notes).

## Documentation

- [Find-TwitchXRef](docs/Find-TwitchXRef.md)
- [Export-XRefData](docs/Export-XRefData.md)
- [Import-XRefData](docs/Import-XRefData.md)
- [Clear-XRefData](docs/Clear-XRefData.md)
- [Enable-XRefPersistence](docs/Enable-XRefPersistence.md)
- [Disable-XRefPersistence](docs/Disable-XRefPersistence.md)

## Known Quirks

- Twitch currently rounds the start of video playback down in chunks (typically up to 10-second intervals). If you visit a video with a timestamp of `1h10m49s`, the video playback itself may start as early as `1h10m40s`.
- Video playback can sometimes start from the beginning of the stream instead of at the timestamp. Try refreshing the page if this happens.
