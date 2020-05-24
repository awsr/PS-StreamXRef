---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/Get-TwitchXRef/blob/module/docs/Find-TwitchXRef.md
schema: 2.0.0
---

# Find-TwitchXRef

## SYNOPSIS
Cross-reference Twitch clips and video timestamps between different channels/users.

## SYNTAX

```
Find-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-Offset <Int32>] -ApiKey <String>
 [<CommonParameters>]
```

## DESCRIPTION
Given a Twitch clip or video timestamp URL, find the same moment from the cross-referenced video or channel and return it as a URL. This only works with stream archives because Twitch returns incorrect data for highlights and etc.

You must provide your own API key.

An event with a `SourceIdentifier` of "**XRefNewDataAdded**" will be sent after running if new data was added to the lookup data cache and an event subscriber has been registered with `Register-EngineEvent`.

## EXAMPLES

### Example 1
```powershell
PS > Find-TwitchXRef -Source "https://clips.twitch.tv/NameOfTheClip" -XRef "ChannelName1" -ApiKey "1234567890abcdefghijklmnopqrst"

https://www.twitch.tv/videos/123456789?t=0h32m54s
```

This will search through ChannelName1's most recent broadcasts and return a URL that goes to the timestamp in their video at the same moment.

### Example 2
```powershell
PS > Find-TwitchXRef -Source "NameOfTheClip" -XRef "https://www.twitch.tv/videos/123456789"

https://www.twitch.tv/videos/123456789?t=0h32m54s
```

This will get the same result as the previous example, but uses just the name of the clip and a specific video to check against.

### Example 3
```powershell
PS > Find-TwitchXRef -Source "https://www.twitch.tv/videos/123456789?t=0h32m54s" -XRef "https://www.twitch.tv/ChannelName2" -Count 60

https://www.twitch.tv/videos/122333444?t=1h04m42s
```

This will search through ChannelName2's 60 most recent broadcasts using a video URL with a timestamp as the source and return the corresponding URL that goes to the same moment from ChannelName2's perspective.

## PARAMETERS

### -Source
Specifies either a Twitch clip URL (or just the ID) or a video URL that includes a timestamp.

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

### -XRef
Accepts either a video URL, a channel URL, or a channel/user name.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Count
Specifies the number of most recent broadcasts to search when `XRef` is a name. (1-100)
Default: 10

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 10
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Offset
Number of results to offset the search range by.
Default: 0

(Useful if the source is older than 100 results.)

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

Used for `Source`, `XRef`, and `ApiKey` parameters. Can be pipelined by property name.

### System.Int32

Used for `Count` and `Offset` parameters. Can be pipelined by property name.

## OUTPUTS

### System.String

If a result is found, the URL will be returned as a string.

## NOTES

The `Source` parameter works with both styles of clip URL that Twitch uses.

## RELATED LINKS
