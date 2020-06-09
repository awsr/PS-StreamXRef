---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/module/docs/Import-XRefLookupData.md
schema: 2.0.0
---

# Import-XRefLookupData

## SYNOPSIS
Import data to the lookup cache. Can also set the API key without invoking a full lookup.

## SYNTAX

### General (Default)
```
Import-XRefLookupData [-Path] <String> [-PassThru] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### ApiKey
```
Import-XRefLookupData [-ApiKey] <String> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This command lets you import data into the lookup cache from a file with JSON formatted data. If you use the `ApiKey` parameter, you can instead import just your API key from a string without having to invoke the main `Find-TwitchXRef` command.

This command is meant to be used with files created using `Export-XRefLookupData`.

## EXAMPLES

### Example 1
```powershell
PS > Import-XRefLookupData -Path JsonFile.json
```

Import previously-exported data from a file.

### Example 2
```powershell
PS > Import-XRefLookupData -ApiKey "1234567890abcdefghijklmnopqrst"
```

Set your API key without invoking the main `Find-TwitchXRef` command.

## PARAMETERS

### -ApiKey
Specifies your API key (for Twitch this is the "Client ID"). Obtained from the [Twitch Developer Dashboard](https://dev.twitch.tv/console/apps/).

```yaml
Type: String
Parameter Sets: ApiKey
Aliases:

Required: True
Position: 0
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Forces overwriting of existing data with imported data if there are differences (except for ones that can't be parsed).

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

### -Path
Specifies the path to a file containing JSON formatted data. Meant for use with `Export-XRefLookupData`.

```yaml
Type: String
Parameter Sets: General
Aliases: PSPath

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -PassThru
When specified, this function will return an object with the results of the import.

```yaml
Type: SwitchParameter
Parameter Sets: General
Aliases:

Required: False
Position: Named
Default value: False
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

### System.String

Only the `Path` parameter supports accepting a value from the pipeline.

## OUTPUTS

### None or System.Array[PSCustomObject]

Returns an array object showing the results of the import operation unless the `Quiet` parameter is set. The statistics are given for "User", "Clip", and "Video" lookup caches.

Each object in the array has a `Name` property as well as counts for `Imported`, `Ignored`, `Skipped`, `Error`, and `Total`.

* Imported: Number of entries successfully imported.
* Ignored: Number of duplicate entries ignored.
* Skipped: Number of entries that had different data than what was already in the cache and were skipped by user.
* Error: Number of entries that could not be parsed.
* Total: Number of entries read.

## NOTES

## RELATED LINKS
