<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍   
#̷𝓍   Write-LogEntry
#̷𝓍   
#>
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$Name
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

        $expectedLocations="$ENV:ProgramData\chocolatey\bin", "${ENV:ToolsRoot}"
        $ffFiles64=$expectedLocations|%{Join-Path $_ 'accesschk64.exe'}
        $ffFiles=$expectedLocations|%{Join-Path $_ 'accesschk.exe'}
        [String[]]$validFiles=@($ffFiles64|?{test-path $_})
        [String[]]$validFiles+=@($ffFiles|?{test-path $_})
        $validFilesCount = $validFiles.Count
        if($validFilesCount){
            return $validFiles[0]
        }
        else{
            return $Null
        }

    }catch{
        Write-Error $_
    }
}



function Get-ServicesEffectivePermissions{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$False, Position=0)]
        [string]$Name
    )

    try{ 
        $ServicesList = @()
        
        if($PSBoundParameters.ContainsKey('Name')){
            $ServicesList = Get-Service | Where-Object -Property Name -imatch "$Name" | select Name
            $ServicesListCount = $ServicesList.Count
            Write-Verbose "ServicesListCount $ServicesListCount"
        }else{
            $ServicesList = Get-Service | select Name
            Write-Verbose "ServicesListCount $ServicesListCount"
        }
        
        [collections.arraylist]$ResultList = [collections.arraylist]::new()
        $appxe =  Get-AccesschkPath
        Write-Verbose "AccesschkPath $appxe"
        ForEach($name in $ServicesList){
            $Res1 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name"          | select -Skip 1) | Out-String
            $Res2 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name" "-l"     | select -Skip 1) | Out-String
            $Res3 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name" "-L"     | select -Skip 1) | Out-String

            $obj = [pscustomobject]@{
                Service = $name
                Permission = $Res1
                SecDesc = $Res2
                SDDL = $Res3
            }
            [void]$ResultList.Add($obj)
        }

        return $ResultList

    }catch{
        Write-Error $_
    }
}





function Get-SrvPermString{
   [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$True, Position=0)]
        [string]$Name
    )

    try{ 
        $ServicesList = @()
        
  
        $ServicesList =(Get-Service | Where-Object -Property Name -imatch "$Name" | select Name).Name
        $ServicesListCount = $ServicesList.Count
        Write-Verbose "ServicesListCount $ServicesListCount"
      
        
      
        $appxe =  Get-AccesschkPath
        Write-Verbose "AccesschkPath $appxe"
        ForEach($name in $ServicesList){
            $Res1 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name"          | select -Skip 1) | Out-String
            $Res2 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name" "-l"     | select -Skip 1) | Out-String
            $Res3 = (&"C:\ProgramData\chocolatey\bin\accesschk64.exe" "-nobanner" "-c" "$name" "-L"     | select -Skip 1) | Out-String


            $ResStr = @"
Service $name

Permission
$Res1

SecDesc
$Res2

SDDL
$Res3   

"@


        }

        return $ResStr

    }catch{
        Write-Error $_
    }
}

Get-SrvPermString $Name