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
Enable-XRefPersistence [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
This function sets up automatic saving for all cached data to a file in the `StreamXRef` folder in your Application Data directory by default. If this file is detected when the module is loaded, persistence will automatically be enabled.

The path for persistence data can be overridden by specifying a path in the `$Env:XRefPersistPath` environment variable. The path must end with ".json" or else it will write an error and use the default path.

Note that automatic saving will only trigger when new data is added to the cache when running the `Find-TwitchXRef` function or if `Import-XRefData` is used with the `Persist` parameter. Additionally, clips and videos older than 60 days will be automatically removed when loaded.

## EXAMPLES

### Example 1
```powershell
PS > Enable-XRefPersistence
```

Enable the built-in data persistence.

## PARAMETERS

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

## RELATED LINKS
