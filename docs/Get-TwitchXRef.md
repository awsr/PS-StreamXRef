---
external help file: Get-TwitchXRef-help.xml
Module Name: Get-TwitchXRef
online version:
schema: 2.0.0
---

# Get-TwitchXRef

## SYNOPSIS
Cross-reference Twitch clips and video timestamps between different channels/users.

## SYNTAX

```
Get-TwitchXRef [-Source] <String> [-XRef] <String> [-Count <Int32>] [-Offset <Int32>] -ClientID <String>
 [<CommonParameters>]
```

## DESCRIPTION
Given a Twitch clip or video timestamp URL, get a URL to the same moment from the cross-referenced video or channel.

You must provide a Client ID the first time the function is run in a session.

## EXAMPLES

## PARAMETERS

### -Source
Accepts Twitch clip URLs (either format), Twitch clip IDs, or video URLs that include a timestamp parameter.

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
Number of videos to search when -XRef is a name.
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

### -ClientID
Accepts your Twitch API client ID.

(REQUIRED when run for the first time in a session, then optional.)

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

## OUTPUTS

## NOTES
This uses the v5 Twitch API.

## RELATED LINKS
