---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/master/docs/Enable-XRefPersistence.md
schema: 2.0.0
---

# Enable-XRefPersistence

## SYNOPSIS
Enables the built-in data persistence option for the StreamXRef module.

## SYNTAX

```
Enable-XRefPersistence [-Compress] [-ExcludeClipMapping] [-Force] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
The `Enable-XRefPersistence` cmdlet sets up automatic saving of cached data to a file (by default this is in the `StreamXRef` folder in your platform's Application Data directory).

When the `StreamXRef` module is loaded, persistence will automatically be enabled if this file is detected.

When persistence is enabled, any data from existing files will be imported. Additionally, clips and videos older than 60 days will be automatically removed.

Note that automatic saving will only trigger when new data is added to the cache when running the `Find-TwitchXRef` cmdlet or if `Import-XRefData` is used with the `Persist` parameter.

See Notes section in `Get-Help Enable-XRefPersistence -Full` for info on overriding the default path.

## EXAMPLES

### Example 1
```powershell
PS > Enable-XRefPersistence
```

Enable the built-in data persistence.

### Example 2
```powershell
PS > Enable-XRefPersistence -Compress -ExcludeClipMapping
```

Use compression on the persistence data file and don't include clip result mappings.

## PARAMETERS

### -Compress
Removes unnecessary whitespace from the persistence data file.

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

### -ExcludeClipMapping
Excludes the cached Clip to Username results from the persistence data file.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: NoMapping, ECM

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Override the formatting parameters for the persistence file.

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
Suppress writing information messages to host.

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

### None

## OUTPUTS

### None

## NOTES

The path for persistence data can be overridden by specifying an absolute path in the `XRefPersistPath` environment variable (`$Env:XRefPersistPath`). If the path does not end in ".json" it will be treated as a directory and the default filename of "datacache.json" will be used. The value is read when the `StreamXRef` module is loaded and when this cmdlet is run.

To revert to the default path, remove the environment variable, set it to `$null`, or set it to an empty string ("") and then run `Enable-XRefPersistence` again.

## RELATED LINKS
