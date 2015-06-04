######################################################################################
# DSC Resource for IIS Server level Application Ppol Defaults
# ApplicationHost.config: system.applicationHost/applicationPools
#
# only a limited number of settings are supported at this time
# We try to cover the most common use cases
# We have a single parameter for each setting
######################################################################################
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
NoWebAdministrationModule=Please ensure that WebAdministration module is installed.
SettingValue=Changing default value '{0}' to '{1}'
ValueOk=Default value '{0}' is already '{1}'
'@
}

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
        [Parameter(Mandatory)]
        [ValidateSet("Machine")]
        [string]$ApplyTo
	)
	
    # Check if WebAdministration module is present for IIS cmdlets
    CheckIISPoshModule

    $getTargetResourceResult = $null;

    $getTargetResourceResult = @{ManagedRuntimeVersion = (GetValue "" "managedRuntimeVersion")
                                    IdentityType = ( GetValue "processModel" "identityType")}    
	return $getTargetResourceResult
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(	
        [ValidateSet("Machine")]
        [parameter(Mandatory = $true)]
        [string]$ApplyTo,
        # in the future there will be another CLR version to allow 
        [ValidateSet("","v2.0","v4.0")]
        [string]$ManagedRuntimeVersion,
        # TODO: we currently don't allow a custom identity
        [ValidateSet("ApplicationPoolIdentity","LocalService","LocalSystem","NetworkService")]
        [string]$IdentityType
    )

        CheckIISPoshModule

        SetValue "" "managedRuntimeVersion" $ManagedRuntimeVersion
        SetValue "processModel" "identityType" $IdentityType
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
	param
	(	
        [ValidateSet("Machine")]
        [parameter(Mandatory = $true)]
        [string]$ApplyTo,
        [ValidateSet("","v2.0","v4.0")]
        [string]$ManagedRuntimeVersion,
        [ValidateSet("ApplicationPoolIdentity","LocalService","LocalSystem","NetworkService")]
        [string]$IdentityType
	)

    [bool]$DesiredConfigurationMatch = $true;

    CheckIISPoshModule

    $DesiredConfigurationMatch = CheckValue "" "managedRuntimeVersion" $ManagedRuntimeVersion
    if (!($DesiredConfigurationMatch)) { return $false }

    $DesiredConfigurationMatch = CheckValue "processModel" "identityType" $IdentityType
    if (!($DesiredConfigurationMatch)) { return $false }
    
	return $DesiredConfigurationMatch
}

Function CheckValue([string]$path,[string]$name,[string]$newValue)
{
    if (!$newValue)
    {
        # if no new value was specified, we assume this value is okay.        
        return $true
    }


    [bool]$DesiredConfigurationMatch = $true;

    $existingValue = GetValue $path $name
    if ($existingValue -ne $newValue)
    {
        $DesiredConfigurationMatch = $false
    }
    else
    {
        $relPath = $path + "/" + $name
        Write-Verbose($LocalizedData.ValueOk -f $relPath,$newValue);
    }
    
    return $DesiredConfigurationMatch
}

# some internal helper function to do the actual work:

Function SetValue([string]$path,[string]$name,[string]$newValue)
{
    if ($newValue)
    {
        $existingValue = GetValue $path $name
        if ($existingValue -ne $newValue)
        {
            if ($path -ne "")
            {
                $path = "/" + $path
            }

            Set-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/applicationPoolDefaults$path" -name $name -value "$newValue"
            $relPath = $path + "/" + $name
            Write-Verbose($LocalizedData.SettingValue -f $relPath,$newValue);
        }
    }
}

Function GetValue([string]$path,[string]$name)
{
    if ($path -ne "")
    {
        $path = "/" + $path
    }

    return Get-WebConfigurationProperty -pspath 'MACHINE/WEBROOT/APPHOST'  -filter "system.applicationHost/applicationPools/applicationPoolDefaults$path" -name $name
}

Function CheckIISPoshModule
{
    # Check if WebAdministration module is present for IIS cmdlets
    if(!(Get-Module -ListAvailable -Name WebAdministration))
    {
        Throw $LocalizedData.NoWebAdministrationModule
    }
}

Export-ModuleMember -Function *-TargetResource