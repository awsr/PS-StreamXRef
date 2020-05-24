---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/Get-TwitchXRef/blob/module/docs/Clear-XRefLookupData.md
schema: 2.0.0
---

# Clear-XRefLookupData

## SYNOPSIS
Clears data from the internal lookup caches for the StreamXRef module.

## SYNTAX

### All (Default)
```
Clear-XRefLookupData [-RemoveAll] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Selection
```
Clear-XRefLookupData [-ApiKey] [-User] [-Clip] [-Video] [-DaysToKeep <Int32>] [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Clears either all data or any combination of the following for the StreamXRef module: Api key, User lookup cache, Clip lookup cache, Video lookup cache.

## EXAMPLES

### Example 1
```
PS > Clear-XRefLookupData -Clip -Video -DaysToKeep 30 -Force
```

This will clear all data from the `Clip` cache and all but those recorded in the last 30 days from the `Video` cache. `Force` is also used prevent being asked to confirm these actions.

## PARAMETERS

### -RemoveAll
Removes the API key and all data from the caches.

```yaml
Type: SwitchParameter
Parameter Sets: All
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
Clear the API key.

```yaml
Type: SwitchParameter
Parameter Sets: Selection
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Clip
Clear the clip lookup cache.

```yaml
Type: SwitchParameter
Parameter Sets: Selection
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -User
Clear the user lookup cache.

```yaml
Type: SwitchParameter
Parameter Sets: Selection
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Video
Clear the video lookup cache.

```yaml
Type: SwitchParameter
Parameter Sets: Selection
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -DaysToKeep
Specifies the number of days to keep when using the `Video` Parameter. If used without `Video` it will have no effect.

```yaml
Type: Int32
Parameter Sets: Selection
Aliases: Keep

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Force clearing data.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

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
