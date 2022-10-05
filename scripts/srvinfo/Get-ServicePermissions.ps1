    <#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍   
#̷𝓍   Write-LogEntry
#̷𝓍   
#>
   [CmdletBinding(SupportsShouldProcess)]
   param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('n')]
        [string]$Name,
        [Parameter(Mandatory=$False)]
        [Alias('j')]
        [switch]$Json
    )

$CurrentPath = (Get-Location).Path
$CmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = '$pid'" | select CommandLine ).CommandLine   
[string[]]$UserCommandArray = $CmdLine.Split(' ')
$ProgramFullPath = $UserCommandArray[0].Replace('"','')
$ProgramDirectory = (gi $ProgramFullPath).DirectoryName
$ProgramName = (gi $ProgramFullPath).Name
$ProgramBasename = (gi $ProgramFullPath).BaseName

$Global:LogFilePath = Join-Path ((Get-Location).Path) 'downloadtool.log'
Remove-Item $Global:LogFilePath -Force -ErrorAction Ignore | Out-Null
New-Item $Global:LogFilePath -Force -ItemType file -ErrorAction Ignore | Out-Null

if(($ProgramName -eq 'pwsh.exe') -Or ($ProgramName -eq 'powershell.exe')){
    $MODE_NATIVE = $False
    $MODE_SCRIPT = $True
}else{
    $MODE_NATIVE = $True
    $MODE_SCRIPT = $False
}




function Out-Banner {  # NOEXPORT
    Write-Host "`n$ProgramBasename - Reports effective permissions for services" -f Blue
    Write-Host "Copyright (C) 2000-2021 Guillaume Plante`n" -f Gray
}
function Out-Usage{  # NOEXPORT
    Write-Host "usage: $ProgramName  [-n name]`n" -f Gray
    Write-Host "The following cmdline options are available:" -f Gray
    Write-Host "`t-help            show help" -f Gray
    Write-Host "`t-n | -Name       name of the service to query" -f Gray
    Write-Host "`t-j | -Json       json format" -f Gray
}



function Get-AccesschkPath{   
    [CmdletBinding(SupportsShouldProcess)]
    param()
    try{
        $accesschkCmd = Get-Command 'accesschk64.exe' -ErrorAction Ignore
        if(($accesschkCmd -ne $Null ) -And (test-path -Path "$($accesschkCmd.Source)" -PathType Leaf)){
            $accesschkApp = $accesschkCmd.Source
            Write-Verbose "✅ Found accesschk64.exe CMD [$accesschkApp]"
            Return $accesschkApp 
        }

        $CurrentPath = (Get-Location).Path
        [string[]]$searchLocations = (gci -Path $CurrentPath -Directory -Depth 1 -Recurse).FullName
        $searchLocations += $CurrentPath
        $searchLocations += "$ENV:ProgramData\chocolatey\bin"
        $searchLocations += "${ENV:ToolsRoot}"
        $sysinternalsAppxPackage = Get-AppxPackage -Name "Microsoft.SysinternalsSuite"
        if($sysinternalsAppxPackage -ne $Null ){
            $sysinternalsSuitePath = Join-Path "$($sysinternalsAppxPackage.InstallLocation)" "Tools"
            $searchLocations += $sysinternalsSuitePath
        }
        $searchLocations  | % { 
            Write-Verbose "search location: $_"
        }

        $ffFiles64=$searchLocations|%{Join-Path $_ 'accesschk64.exe'}
        $ffFiles=$searchLocations|%{Join-Path $_ 'accesschk.exe'}
        [String[]]$validFiles=@($ffFiles64|?{test-path $_})
        [String[]]$validFiles+=@($ffFiles|?{test-path $_})
        $validFilesCount = $validFiles.Count
        if($validFilesCount){
            Write-Verbose "found $validFilesCount valid paths.. return $validFiles[0]"
            $validFiles  | % { 
                Write-Verbose "Valid Files: $_"
            }
            return $validFiles[0]
        }
    
        Throw "Could not locate accesschk64.exe"

    }catch{
        Write-Error $_
    }
}



function Get-ServicesPermissions{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$False, Position=0)]
        [Alias('n')]
        [string]$Filter
    )

    try{ 
        $ServicesList = @()
        
        if($PSBoundParameters.ContainsKey('Filter')){
            $ServicesList = (Get-Service | Where-Object -Property Name -imatch "$Filter" | select Name).Name
            $ServicesListCount = $ServicesList.Count
            Write-Verbose "ServicesListCount $ServicesListCount"
        }else{
            $ServicesList = (Get-Service | select Name).Name
            Write-Verbose "ServicesListCount $ServicesListCount"
        }
        
        [collections.arraylist]$ResultList = [collections.arraylist]::new()
        $AccesschkExe =  Get-AccesschkPath
        Write-Verbose "AccesschkPath $AccesschkExe"
        ForEach($name in $ServicesList){
            $Res1 = (&"$AccesschkExe" "-nobanner" "-c" "$name"          | select -Skip 1) | Out-String
            $Res2 = (&"$AccesschkExe" "-nobanner" "-c" "$name" "-l"     | select -Skip 1) | Out-String
            $Res3 = (&"$AccesschkExe" "-nobanner" "-c" "$name" "-L"     | select -Skip 1) | Out-String

            $Res1 = $Res1.Trim()
            $Res2 = $Res2.Trim()
            $Res3 = $Res3.Trim()

            $obj = [pscustomobject]@{
                Service             = $name
                Permission          = $Res1
                SecurityDescriptor  = $Res2
                SDDL                = $Res3
            }
            [void]$ResultList.Add($obj)
        }

        return $ResultList

    }catch{
        Write-Error $_
    }
}

function Test-ServiceValidity{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('n')]
        [string]$Name
    )
    $Res = Get-Service | Where Name -eq "$Name" -ErrorAction Ignore
    if($Null -eq $Res){
        return $false
    }

    return $True
}


function Get-SvcPermissionsAsHashTable{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('n')]
        [string]$Name
    )

    try{ 
        if(-not(Test-ServiceValidity $Name)){ return $Null }
        $AccesschkExe =  Get-AccesschkPath

        $Res1 = (&"$AccesschkExe" "-nobanner" "-c" "$Name"          | select -Skip 1) | Out-String
        $Res2 = (&"$AccesschkExe" "-nobanner" "-c" "$Name" "-l"     | select -Skip 1) | Out-String
        $Res3 = (&"$AccesschkExe" "-nobanner" "-c" "$Name" "-L"     | select -Skip 1) | Out-String

        $Res1 = $Res1.Trim()
        $Res2 = $Res2.Trim()
        $Res3 = $Res3.Trim()
            
        [hashtable]$hash = [ordered]@{
            Service             = $Name;
            Permission          = $Res1;
            SecurityDescriptor  = $Res2;
            SDDL                = $Res3;
        }
        return $hash
            
    }catch{
        Write-Error $_
    }
}



function Get-SvcPermissionsAsJson{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('n')]
        [string]$Name
    )

    try{ 
        if(-not(Test-ServiceValidity $Name)){ return $Null }
        $AccesschkExe =  Get-AccesschkPath

        $Res1 = (&"$AccesschkExe" "-nobanner" "-c" "$Name"          | select -Skip 1) | Out-String
        $Res2 = (&"$AccesschkExe" "-nobanner" "-c" "$Name" "-l"     | select -Skip 1) | Out-String
        $Res3 = (&"$AccesschkExe" "-nobanner" "-c" "$Name" "-L"     | select -Skip 1) | Out-String

        $Res1 = $Res1.Trim()
        $Res2 = $Res2.Trim()
        $Res3 = $Res3.Trim()
            
        $obj = [pscustomobject]@{
            Service             = $Name
            Permission          = $Res1
            SecurityDescriptor  = $Res2
            SDDL                = $Res3
        }
        $JsonStr = $obj | ConvertTo-Json 
        return $JsonStr
            
    }catch{
        Write-Error $_
    }
}



if($Help){
    Out-Banner
    Out-Usage
    return
}


if($Json){
    Get-SvcPermissionsAsJson $Name
}else{
    Get-SvcPermissionsAsHashTable $Name
}

