---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/Get-TwitchXRef/blob/module/docs/Export-XRefLookupData.md
schema: 2.0.0
---

# Export-XRefLookupData

## SYNOPSIS
{{ Fill in the Synopsis }}

## SYNTAX

### Object (Default)
```
Export-XRefLookupData [-Compress] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### File
```
Export-XRefLookupData [-Path] <String> [-Force] [-Compress] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Exports the contents of the lookup data cache as JSON to a specified file.

The files created by this command can be used with `Import-XRefLookupData`.

## EXAMPLES

### Example 1
```
PS > {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Compress
Removes unnecessary whitespace from the JSON string output. This results in smaller files at the expense of readability.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
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

### -Force
{{ Fill Force Description }}

```yaml
Type: SwitchParameter
Parameter Sets: File
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Path
{{ Fill Path Description }}

```yaml
Type: String
Parameter Sets: File
Aliases: PSPath

Required: True
Position: 0
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
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

You can pipeline a value for `Path` either as a string or by property name.

### System.Management.Automation.SwitchParameter

Used for `Force` and `Compress` parameters. You can pipeline a boolean to these values by property name.

## OUTPUTS

### None

## NOTES

## RELATED LINKS
