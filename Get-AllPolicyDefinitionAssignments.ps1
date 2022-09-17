
function Get-AllPolicyDefinitionAssignments {
    param (
        [CmdletBinding()]
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [String]$TenantId
    )

    Begin {
        Set-AzContext -TenantId $TenantId -Verbose | Out-Null
        $allSubscriptions = @()
        $allManagementGroups = @()
        $allMgAssignments = @()
        $allSubAssignments = @()

        $allSubscriptions = Get-AzSubscription -TenantId $TenantId -Verbose
        $allManagementGroups = Get-AzManagementGroup -Verbose
        #$FilterAssignedBy = 'Security Center'

        foreach($item in $allManagementGroups){
            $allMgAssignments += @{
                Name = $item.DisplayName
                Id = $item.Id
                Assignments = Get-AzPolicyAssignment -Scope $item.Id -WarningAction SilentlyContinue -Verbose #| Where-Object {$_.Properties.Metadata.assignedBy -ne $FilterAssignedBy}
            }
        }


        foreach($item in $allSubscriptions){
            $assignments = $null
            Select-AzSubscription $item -WarningAction SilentlyContinue -Verbose | Set-AzContext -Verbose | Out-Null
            $assignments = Get-AzPolicyAssignment -Scope "/subscriptions/$($item.Id)" -IncludeDescendent -WarningAction SilentlyContinue -Verbose #| Where-Object {$_.Properties.Metadata.assignedBy -ne $FilterAssignedBy}
            $allSubAssignments += @{
                Name = $item.Name
                Id = $item.Id
                Assignments = $assignments
            }
        }
    }
    Process {
        $allAssignedMgDefinitions = @()
        $allAssignedSubDefinitions = @()


        foreach ($item in $allMgAssignments){
            $allAssignedDefinitions = @()
            foreach($assignment in $item.Assignments){
                $allAssignedDefinitions += $assignment.Properties.PolicyDefinitionId
            }
            $allAssignedMgDefinitions += @{
                Name = $item.Name
                Id = $item.Id
                Definitions = $allAssignedDefinitions
            }
        }

        foreach ($item in $allSubAssignments){
            $allAssignedDefinitions = @()
            foreach($assignment in $item.Assignments){
                $allAssignedDefinitions += $assignment.Properties.PolicyDefinitionId
            }
            $allAssignedSubDefinitions += @{
                Name = $item.Name
                Id = $item.Id
                Definitions = $allAssignedDefinitions
            }
            
        }
    }
    End {
        
        $subResults = @()
        $mgResults = @()
        
        
        foreach($item in $allAssignedMgDefinitions){
            $assignments = ($allMgAssignments | Where-Object {$_.Id -eq $item.Id}).Assignments
            $matchingAssinments = @()
            foreach($definitionId in $item.Definitions){
                $matchingAssinments += @{
                    DefinitionId = $definitionId
                    Assignments = @(($assignments | Where-Object {$_.Properties.PolicyDefinitionId -eq $definitionId}).ResourceId)
                }
            }
        
            $mgResults += @{
                Name = $item.Name
                Id = $item.Id
                Policies = $matchingAssinments
            }
        }
        
        foreach($item in $allAssignedSubDefinitions){
            $assignments = ($allSubAssignments | Where-Object {$_.Id -eq $item.Id}).Assignments
            $matchingAssinments = @()
            foreach($definitionId in $item.Definitions){
                $matchingAssinments += @{
                    DefinitionId = $definitionId
                    Assignments = @(($assignments | Where-Object {$_.Properties.PolicyDefinitionId -eq $definitionId}).ResourceId)
                }
            }
        
            $subResults += @{
                Name = $item.Name
                Id = $item.Id
                Policies = $matchingAssinments
            }
        }
        
        foreach($item in $mgResults){
            $definitionCount = $item.Policies.Count
            $assignmentCount = 0
            foreach($policy in $item.Policies){
                $assignmentCount += $policy.Assignments.Count
                Write-Verbose "[DefinitionId] $($policy.DefinitionId)"
                foreach($assignment in $policy.Assignments){
                    Write-Verbose "[AssignmentId] $($assignment)"
                }
            }
            Write-Verbose "Found '$definitionCount' total definitions in Management Group '$($item.Name)' with Id '$($item.Id)'"
            Write-Verbose "Found '$assignmentCount' total assignments in Management Group '$($item.Name)' with Id '$($item.Id)'"
        }
        
        foreach($item in $subResults){
            $definitionCount = $item.Policies.Count
            $assignmentCount = 0
            foreach($policy in $item.Policies){
                $assignmentCount += $policy.Assignments.Count
                Write-Verbose "[DefinitionId] $($policy.DefinitionId)"
                foreach($assignment in $policy.Assignments){
                    Write-Verbose "[AssignmentId] $($assignment)"
                }
            }
            Write-Verbose "Found '$definitionCount' total definitions in Subscription '$($item.Name)' with Id '$($item.Id)'"
            Write-Verbose "Found '$assignmentCount' total assignments in Subscription '$($item.Name)' with Id '$($item.Id)'"
        }
        
        return @{
            managementGroups = $mgResults
            subscriptions = $subResults
        }
    }

}

Connect-AzAccount
$TenandId = ''
$result = Get-AllPolicyDefinitionAssignments -TenantId $TenandId -Verbose
