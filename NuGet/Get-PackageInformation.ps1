[CmdletBinding()]
Param(  
    [Parameter(Position = 0, ValueFromPipeline=$true)]
    [string[]]
    $paths = ".",
    [string]
    $source = "nuget.org",
    [switch]
    $IncludeDependencies,
    [string]
    $outputPath = "."
)

#Get-Package | Select -Unique @{name="Name";expression={$_.Id}},@{name="Version";expression={$_.Version.Version.tostring()}},@{name="ComponentUri";expression={"https://www.nuget.org/packages/$($_.Id)/"}},LicenseUri | convertto-json

$global:packagesFromConfigs = @()

foreach ($path in $paths) {
    Write-Verbose "Gathering package information in '$path'..."

    $configs = Get-ChildItem -Path $path packages.config -Recurse

    foreach ($config in $configs) {
        [xml]$configContent = Get-Content $config.FullName
        $configContent.GetElementsByTagName("package") | ForEach-Object { $global:packagesFromConfigs += $_ }
    }
}

$global:packagesFromConfigs = $global:packagesFromConfigs | Sort-Object Id,Version -Unique | Select-Object Id,Version

$finalPackages = @()

Write-Progress -Activity "Collecting package information" -status "Starting" -percentComplete 0
$i = 0

foreach ($packageFromConfig in $global:packagesFromConfigs) {
    $i++;
    Write-Progress -Activity "Collecting package information" -status "Gathering details for $($packageFromConfig.id)" -percentComplete ($i / $global:packagesFromConfigs.Count * 100)

    Write-Verbose "Gathering details for $($packageFromConfig.id) ($($packageFromConfig.version))..."
    $packages = Find-Package $packageFromConfig.id -ProviderName NuGet -RequiredVersion $packageFromConfig.version -IncludeDependencies:$IncludeDependencies.IsPresent -Source $source

    if ($packages -eq $null) {
        Write-Warning "Package $($packageFromConfig.id) ($($packageFromConfig.version)) not found."
        continue
    }

    $package = $packages[0]

    Write-Verbose "Processing $($package.name) ($($package.version))..."

    Write-Verbose "Getting links"
    $projectLink = $package.Links | Where-Object {$_.Relationship -eq 'project'}
    $licenseLink = $package.Links | Where-Object {$_.Relationship -eq 'license'}

    if ($projectLink -eq $null) {
        $projectUri = ""
    }
    else {
        $projectUri = $projectLink.HRef
    }

    if ($licenseLink -eq $null) {
        Write-Warning "No license link found for $($package.name) ($($package.version))."
        #Write-Output $package.Links | Select-Object href,relationship
        $licenseUri = ""
    }
    else {
        Write-Verbose "Getting license from: $licenseLink"
        $licenseUri = $licenseLink.HRef
        #$license = Invoke-WebRequest $licenseUri | Out-Null            
    }

    #Write-Output $package
    $finalPackage = $package | Select-Object Name,Version,@{name="ComponentUri";expression={$projectUri}},@{name="LicenseUri";expression={$licenseUri}}

    Write-Verbose "Final package information: $finalPackage"
    Write-Verbose "Processed $($package.name) ($($package.version))."
    $finalPackages += $finalPackage

    Write-Verbose "Gathered details for $($packageFromConfig.id) ($($packageFromConfig.version))."
}

Write-Progress -Activity "Collecting package information" -status "Finished" -percentComplete 100

Write-Verbose "Gathered package information in '$path'."

#Write-Output $finalPackages

#$package | get-member
#Write-Output $package.Metadata.Keys
#Write-Output $package.Attributes.Keys
#$package.Links | % { $_ }
#$package.Links | Write-Output
#$licenseLink = $package.Links | Where-Object {$_.Relationship -eq 'license'}
#Write-Output $licenseLink.HRef

ConvertTo-Json $finalPackages | Out-File (Join-Path $outputPath "ThirdPartyComponents.json") -Encoding utf8

return $finalPackages