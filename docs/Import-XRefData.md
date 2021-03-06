---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/master/docs/Import-XRefData.md
schema: 2.0.0
---

# Import-XRefData

## SYNOPSIS
Import data to the lookup cache.

## SYNTAX

### General (Default)
```
Import-XRefData [-Path] <String> [-PassThru] [-Persist] [-Quiet] [-Force] [<CommonParameters>]
```

### ApiKey
```
Import-XRefData [-ApiKey] <String> [-Persist] [-Quiet] [-Force] [<CommonParameters>]
```

## DESCRIPTION
The `Import-XRefData` cmdlet lets you import data into the lookup cache from a JSON file that was made using `Export-XRefData`. If you use the `ApiKey` parameter, you can instead import just your API key from a string without having to invoke the main `Find-TwitchXRef` cmdlet.

This cmdlet does not send an "**XRefNewDataAdded**" event when new data is added unless the `Persist` parameter is used.

## EXAMPLES

### Example 1
```powershell
PS > Import-XRefData -Path JsonFile.json
```

Import previously-exported data from a file.

### Example 2
```powershell
PS > Import-XRefData -ApiKey "1234567890abcdefghijklmnopqrst"
```

Set your API key without invoking the main `Find-TwitchXRef` cmdlet.

### Example 3
```powershell
PS > $Results = Import-XRefData -Path JsonFile.json -PassThru
PS > $Results.Values | Format-Table

Name  Imported Skipped Error Total
----  -------- ------- ----- -----
User         4      12     0    16
Clip         7       2     0     9
Video        5       1     0     6
```

Save the results of importing and display them later as a table.

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
Forces overwriting of existing data in the Clip, User, and Video lookup caches.

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
Specifies the path to a file containing JSON formatted data. Meant for use with `Export-XRefData`.

```yaml
Type: String
Parameter Sets: General
Aliases: PSPath

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -PassThru
When specified, this cmdlet will return an object with the results of the import.

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

### -Persist
Enables sending an **XRefNewDataAdded** event after new data is imported if there's a registered event subscriber (or if persistence is enabled).

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

### -Quiet
Suppress writing import results to host as well as per-item warning messages (but not errors).

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

Only the `Path` parameter supports accepting a value from the pipeline.

## OUTPUTS

### None or StreamXRef.ImportResults

When the `PassThru` parameter is specified, this cmdlet returns a `[StreamXRef.ImportResults]` object (based on `[System.Collections.Generic.Dictionary]`) with the results of the import operation. Use `AllImported`, `AllSkipped`, `AllError`, or `AllTotal` properties to get the counts across all of the caches.

Each object includes counts for `Imported`, `Skipped`, `Error`, and `Total`.

* Imported: Number of entries successfully imported.
* Skipped: Number of duplicate entries skipped.
* Error: Number of entries that conflicted or could not be parsed and were not imported.
* Total: Number of entries read.

## NOTES

Clip to Username mappings are considered low priority and any errors with them will only trigger a warning message at the end of the import.

## RELATED LINKS
