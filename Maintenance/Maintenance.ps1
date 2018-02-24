#Requires -version 4.0
#Requires -runasadministrator

function UpdateNgen() {
    Write-Output UpdateNgen

    $netDir = Join-Path $env:windir "Microsoft.NET"
    $frameworkDirs = @((Join-Path $netDir "Framework"))
    if ([Environment]::Is64BitOperatingSystem) {
        $frameworkDirs += (Join-Path $netDir "Framework64")
    }
    $netVersions = @("v2.0.50727", "v3.0", "v3.5", "v4.0.30319")

    foreach ($netVersion in $netVersions) {
        Write-Output "Updating: $netversion"

        foreach ($frameworkDir in $frameworkDirs) {
            $currentPath = Join-Path $frameworkDir $netVersion
            Write-Output $currentPath
    
            Push-Location $currentPath
            if (Test-Path ./ngen.exe) {
                &./ngen.exe update /nologo /force /queue
                &./ngen.exe executequeueditems /nologo
            }
            else {
                Write-Warning "No ngen.exe found"
            }
            Pop-Location
        }
    }
}

function CleanTempDirs() {
    Write-Output CleanTempDirs

    for ($i=1; $i -le 10; $i++) {
        # System-Temp
        Get-Childitem (Join-Path $env:windir temp) -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        # User-Temp
        Get-Childitem $env:temp -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function CleanFiles() {
    Write-Output CleanTempDirs

    cleanmgr.exe /sagerun:65535
}

#CleanTempDirs

#CleanFiles

UpdateNgen