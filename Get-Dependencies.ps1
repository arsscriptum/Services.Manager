

if(-not([string]::IsNullOrEmpty("$ENV:MyCode"))){
    Push-Location "$ENV:MyCode"    
    $GitExe = (Get-Command 'git.exe').Source
    &"$GitExe" "clone" "https://github.com/Win32-WTL/WTL.git"
    Set-EnvironmentVariable -Name "WTL_ROOT" -Value "$ENV:MyCode\WTL" -Scope User
    Set-EnvironmentVariable -Name "WTL_INCLUDE" -Value "$ENV:MyCode\WTL\Include" -Scope User
}


&"$GitExe" 'submodule' 'update' '--init'
Set-EnvironmentVariable -Name "BZSLIB_PATH" -Value "$PSScriptRoot\ext\BazisLib" -Scope User