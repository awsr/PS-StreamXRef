---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/master/docs/Find-TwitchXRef.md
schema: 2.0.0
---

# Find-TwitchXRef

## SYNOPSIS
Cross-reference Twitch clips and video timestamps between different channels/users.

## SYNTAX

```
Find-TwitchXRef [-Source] <String> [-Target] <String> [-Count <Int32>] [-Offset <Int32>] [-Force]
 -ApiKey <String> [<CommonParameters>]
```

## DESCRIPTION
Given a Twitch clip or video timestamp URL, find the same moment from the cross-referenced video or channel and return it as a URL. This only works with stream archives because Twitch returns incorrect data for highlights and etc.

You must provide your own API key. For Twitch this is the "Client ID" and can be obtained from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

An event with a `SourceIdentifier` of "**XRefNewDataAdded**" will be sent after running if new data was added to the lookup data cache and an event subscriber has been registered with `Register-EngineEvent`.

## EXAMPLES

### Example 1
```powershell
PS > Find-TwitchXRef -Source "https://clips.twitch.tv/NameOfTheClip" -Target "ChannelName1" -ApiKey "1234567890abcdefghijklmnopqrst"

https://www.twitch.tv/videos/123456789?t=0h32m54s
```

This will search through ChannelName1's most recent broadcasts and return a URL that goes to the timestamp in their video at the same moment.

### Example 2
```powershell
PS > Find-TwitchXRef -Source "NameOfTheClip" -Target "https://www.twitch.tv/videos/123456789"

https://www.twitch.tv/videos/123456789?t=0h32m54s
```

This will get the same result as the previous example, but uses just the name of the clip and a specific video to check against.

### Example 3
```powershell
PS > Find-TwitchXRef -Source "https://www.twitch.tv/videos/123456789?t=0h32m54s" -Target "https://www.twitch.tv/ChannelName2" -Count 60

https://www.twitch.tv/videos/122333444?t=1h04m42s
```

This will search through ChannelName2's 60 most recent broadcasts using a video URL with a timestamp as the source and return the corresponding URL that goes to the same moment from ChannelName2's perspective.

### Example 4
```powershell
PS > Find-TwitchXRef "v/123456789?t=32m54s" "ChannelName2" -Count 60

https://www.twitch.tv/videos/122333444?t=1h04m42s
```

This is the same search as shown in Example 3, but abbreviated using the shorthand syntax for videos.

## PARAMETERS

### -Source
Specifies what you're using for your point of reference. Accepts either a Twitch clip (as a URL or just the ID) or an archived Twitch broadcast with timestamp (as a URL or shorthand "v/...").

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Target
Specifies where you want to perform the cross-reference lookup. Accepts either a Twitch channel/user (as a URL or just the name) or a Twitch video (as a URL or shorthand "v/...").

```yaml
Type: String
Parameter Sets: (All)
Aliases: XRef

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Count
Specifies the number of most recent broadcasts to search when `Target` is a name. (1-100)
Default: 20

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 20
Accept pipeline input: False
Accept wildcard characters: False
```

### -Offset
Specifies the number of results to offset the search range by.
Default: 0

(Useful if the source is older than 100 results.)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
Accepts your API key (for Twitch this is the "Client ID"). Required when one hasn't already been provided. Obtained from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
When specified, this cmdlet will skip reading from the internal lookup cache.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExplicitNull
When specified, this cmdlet will explicitly return a value of `$null` when encountering a predefined error (see Notes section in `Get-Help Find-TwitchXRef -Full`). This can be helpful when used in an environment where `Set-StrictMode` is enabled.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: en

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

Used for `Source`, `Target`, and `ApiKey` parameters. Can be pipelined by property name.

### System.Int32

Used for `Count` and `Offset` parameters.

## OUTPUTS

### System.String

If a result is found, the URL will be returned as a string.

### Void (Null)

If `ExplicitNull` is specified and a predefined error occurs, a null value will be returned

## NOTES

The `Source` parameter works with both styles of clip URL that Twitch uses.

The following ErrorIds are defined:
* `MissingTimestamp`: The `Source` video URL is missing a timestamp parameter. ("...t=1h23m45s")
* `VideoNotFound`: The originating video the source clip came from is unavailable or deleted.
* `InvalidVideoType`: The source, originating, or `Target` video is not an archived broadcast.
* `UserNotFound`: The user/channel name given for `Target` wasn't found.
* `EventNotInRange`: The `Source` event happened before the earliest video returned by Twitch API.
* `EventNotFound`: The `Source` event happened when the user/channel wasn't broadcasting.

The FullyQualifiedErrorId will be in the format of `<ErrorId>,Find-TwitchXRef`.

When one of these errors occur, the cmdlet will move on to the next item from the pipeline (if any). If `ExplicitNull` is specified, the cmdlet will first return a value of `$null` before moving on to the next item.

## RELATED LINKS
