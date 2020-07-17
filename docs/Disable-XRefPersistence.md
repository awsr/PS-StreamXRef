---
external help file: StreamXRef-help.xml
Module Name: StreamXRef
online version: https://github.com/awsr/PS-StreamXRef/blob/master/docs/Disable-XRefPersistence.md
schema: 2.0.0
---

# Disable-XRefPersistence

## SYNOPSIS
Disables the built-in data persistence option for the StreamXRef module.

## SYNTAX

```
Disable-XRefPersistence [-Quiet] [-Remove] [<CommonParameters>]
```

## DESCRIPTION
Disables the built-in data persistence option by renaming the file and unregistering the event subscriber. The `Remove` parameter can be specified to delete all persistent data files.

## EXAMPLES

### Example 1
```powershell
PS > Disable-XRefPersistence
```

Disable the built-in data persistence.

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

### -Remove
Delete the data file instead of renaming it when disabling persistence (or delete the renamed file if persistence is already disabled).

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
