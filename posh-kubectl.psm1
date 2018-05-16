$global:KubectlCompletion = @{}

$script:flagRegex = "^  (-[^, =]+),? ?(--[^= ]+)?"

function script:Get-AutoCompleteResult
{
    param([Parameter(ValueFromPipeline=$true)] $value)
    
    Process
    {
        New-Object System.Management.Automation.CompletionResult $value
    }
}

filter script:MatchingCommand($commandName)
{
    if ($_.StartsWith($commandName))
    {
        $_
    }
}

$Completion_Kubectl = {
    param($commandName, $commandAst, $cursorPosition)

    $command = $null
    $commandParameters = @{}
    $state = "Unknown"
    $wordToComplete = $commandAst.CommandElements | Where-Object { $_.ToString() -eq $commandName } | Foreach-Object { $commandAst.CommandElements.IndexOf($_) }

    for ($i=1; $i -lt $commandAst.CommandElements.Count; $i++)
    {
        $p = $commandAst.CommandElements[$i].ToString()

        if ($p.StartsWith("-"))
        {
            if ($state -eq "Unknown" -or $state -eq "Options")
            {
                $commandParameters[$i] = "Option"
                $state = "Options"
            }
            else
            {
                $commandParameters[$i] = "CommandOption"
                $state = "CommandOptions"
            }
        } 
        else 
        {
            if ($state -ne "CommandOptions")
            {
                $commandParameters[$i] = "Command"
                $command = $p
                $state = "CommandOptions"
            } 
            else 
            {
                $commandParameters[$i] = "CommandOther"
            }
        }
    }

    if ($global:KubectlCompletion.Count -eq 0)
    {
        $global:KubectlCompletion["commands"] = @{}
        $global:KubectlCompletion["options"] = @()
        
        kubectl --help | ForEach-Object {
            Write-Output $_
            if ($_ -match "^\s{2,3}(\w+)\s+(.+)")
            {
                $global:KubectlCompletion["commands"][$Matches[1]] = @{}
                
                $currentCommand = $global:KubectlCompletion["commands"][$Matches[1]]
                $currentCommand["options"] = @()
            }
            elseif ($_ -match $flagRegex)
            {
                $global:KubectlCompletion["options"] += $Matches[1]
                if ($Matches[2] -ne $null)
                {
                    $global:KubectlCompletion["options"] += $Matches[2]
                 }
            }
        }

    }
    
    if ($wordToComplete -eq $null)
    {
        $commandToComplete = "Command"
        if ($commandParameters.Count -gt 0)
        {
            if ($commandParameters[$commandParameters.Count] -eq "Command")
            {
                $commandToComplete = "CommandOther"
            }
        } 
    } else {
        $commandToComplete = $commandParameters[$wordToComplete]
    }

    switch ($commandToComplete)
    {
        "Command" { $global:KubectlCompletion["commands"].Keys | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult }
        "Option" { $global:KubectlCompletion["options"] | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult }
        "CommandOption" { 
            $options = $global:KubectlCompletion["commands"][$command]["options"]
            if ($options.Count -eq 0)
            {
                kubectl $command --help | % {
                if ($_ -match $flagRegex)
                    {
                        $options += $Matches[1]
                        if ($Matches[2] -ne $null)
                        {
                            $options += $Matches[2]
                        }
                    }
                }
            }

            $global:KubectlCompletion["commands"][$command]["options"] = $options
            $options | MatchingCommand -Command $commandName | Sort-Object | Get-AutoCompleteResult
        }
        "CommandOther" {
            $filter = $null
            switch ($command)
            {
                "start" { FilterContainers $commandName "status=created", "status=exited" }
                "stop" { FilterContainers $commandName "status=running" }
                { @("run", "rmi", "history", "push", "save", "tag") -contains $_ } { CompleteImages $commandName }
                default { FilterContainers $commandName }
            }
            
        }
        default { $global:KubectlCompletion["commands"].Keys | MatchingCommand -Command $commandName }
    }
}

# Register the TabExpension2 function
if (-not $global:options) { $global:options = @{CustomArgumentCompleters = @{};NativeArgumentCompleters = @{}}}
$global:options['NativeArgumentCompleters']['kubectl'] = $Completion_Kubectl

$function:tabexpansion2 = $function:tabexpansion2 -replace 'End\r\n{','End { if ($null -ne $options) { $options += $global:options} else {$options = $global:options}'