---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/master/docs/Clear-XRefData.md
schema: 2.0.0
---

# Clear-XRefData

## SYNOPSIS
Clears data from the internal lookup cache for the StreamXRef module.

## SYNTAX

### Selection (Default)
```
Clear-XRefData -Name <String[]> [-DaysToKeep <Int32>] [<CommonParameters>]
```

### All
```
Clear-XRefData [-RemoveAll] [<CommonParameters>]
```

## DESCRIPTION
The `Clear-XRefData` cmdlet clears either all data or any combination of the following for the `StreamXRef` module: API key, User lookup cache, Clip lookup cache, Video lookup cache.

## EXAMPLES

### Example 1
```
PS > Clear-XRefData -Name Clip, Video -DaysToKeep 30
```

This will clear data older than 30 days from the `Clip` and `Video` caches.

## PARAMETERS

### -Name
Specify which data to clear. Accepts the folowing values:

- ApiKey
- Clip
- User
- Video

```yaml
Type: String[]
Parameter Sets: Selection
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -DaysToKeep
Specifies the number of days to keep in the `Clip` and `Video` caches. If used without at least one of these it will have no effect. (Recommended max value: 60)

```yaml
Type: Int32
Parameter Sets: Selection
Aliases: Keep

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -RemoveAll
Remove the API key and all cached data.

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

## OUTPUTS

### None

## NOTES

## RELATED LINKS
