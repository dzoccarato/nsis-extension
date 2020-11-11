$scriptFile = Get-VstsInput -Name scriptFile -Require;
$justInclude = Get-VstsInput -Name justInclude -Require;
$arguments = Get-VstsInput -Name arguments;
$includeMorePlugins = Get-VstsInput -Name includeMorePlugins -Require;
$includeCustomPluginsPath = Get-VstsInput -Name includeCustomPluginsPath -Require;

Write-Host "scriptFile = $(scriptFile)"
Write-Host "justInclude = $(justInclude)"
Write-Host "arguments = $(arguments)"
Write-Host "includeMorePlugins = $(includeMorePlugins)"
Write-Host "includeCustomPluginsPath = $(includeCustomPluginsPath)"
#foreach ($key in $PSBoundParameters.Keys) {
#    Write-Host ($key + ' = ' + $PSBoundParameters[$key])
#}

$path = split-path $MyInvocation.MyCommand.Path

$output = $path + "\nsis.zip"

$destination = $path + "\nsis"

if (!(Test-Path $destination)) {

    $start_time = Get-Date

    Add-Type -assembly "system.io.compression.filesystem"

    [io.compression.zipfile]::ExtractToDirectory($output, $destination)

    $directories = Get-ChildItem -Path $destination
    $nsis3Directory = $directories[0].FullName
    
    Write-Output "Time taken (Unzip): $((Get-Date).Subtract($start_time).Seconds) second(s)"
}
else {
    $directories = Get-ChildItem -Path $destination
    $nsis3Directory = $directories[0].FullName
}

if ($includeMorePlugins -eq "yes") {

    # Copy ansi plugin folder
    $pluginPath = $path + "\plugins\x86-ansi\*"
    $pluginOutput = $nsis3Directory + "\plugins\x86-ansi"
    Copy-Item $pluginPath $pluginOutput -force

    Write-Output "[includeMorePlugins] dump 'plugins\x86-ansi':"
    Get-ChildItem $nsis3Directory + "\plugins\x86-ansi"
    
    # Copy unicode plugin folder
    $pluginPath = $path + "\plugins\x86-unicode\*"
    $pluginOutput = $nsis3Directory + "\plugins\x86-unicode"
    Copy-Item $pluginPath $pluginOutput -force

    Write-Output "[includeMorePlugins] dump 'plugins\x86-unicode':"
    Get-ChildItem $nsis3Directory + "\plugins\x86-unicode"
}
    
if (-Not ([string]::IsNullOrEmpty($includeCustomPluginsPath))) {

    $hasAnsiPath = Test-Path $includeCustomPluginsPath + '\x86-ansi';
    $hasUnicodePath = Test-Path $includeCustomPluginsPath + '\x86-unicode';
    
    # Has ansi plugin folder, copy in appropriate out folder
    if ($hasAnsiPath) {
        Write-Output "[includeCustomPluginsPath - x86-ansi detected] dump '$(includeCustomPluginsPath)\x86-ansi':"
        Get-ChildItem $includeCustomPluginsPath + '\x86-ansi'
        
        $pluginPath = $includeCustomPluginsPath + "\x86-ansi\*"
        $pluginOutput = $nsis3Directory + "\plugins\x86-ansi"
        Copy-Item $pluginPath $pluginOutput -force
        
        Write-Output "[includeCustomPluginsPath] dump 'plugins\x86-ansi':"
        Get-ChildItem $nsis3Directory + "\plugins\x86-ansi"
    }
    
    # Has unicode plugin folder, copy in appropriate out folder
    if ($hasUnicodePath) {
        Write-Output "[includeCustomPluginsPath - x86-unicode detected] dump '$(includeCustomPluginsPath)\x86-unicode':"
        Get-ChildItem $includeCustomPluginsPath + '\x86-unicode'
        
        $pluginPath = $includeCustomPluginsPath + "\x86-unicode\*"
        $pluginOutput = $nsis3Directory + "\plugins\x86-unicode"
        Copy-Item $pluginPath $pluginOutput -force
        
        Write-Output "[includeCustomPluginsPath] dump 'plugins\x86-unicode':"
        Get-ChildItem $nsis3Directory + "\plugins\x86-unicode"
    }

    # No ansi/unicode path provided, interpret it as ansi to be backward compatible
    if (-Not $hasAnsiPath -and -Not $hasUnicodePath) {
        Write-Output "[includeCustomPluginsPath - no x86-ansi, no x86-unicode detected - fallback to x86-ansi] dump '$(includeCustomPluginsPath)':"
        Get-ChildItem $includeCustomPluginsPath

        $pluginPath = $includeCustomPluginsPath + "\*"
        $pluginOutput = $nsis3Directory + "\plugins\x86-ansi"
        Copy-Item $pluginPath $pluginOutput -force

        Write-Output "[includeCustomPluginsPath] dump 'plugins\x86-ansi':"
        Get-ChildItem $nsis3Directory + "\plugins\x86-ansi"
    }
}

$nsis3Exe = $nsis3Directory + "\makensis.exe"

$env:NSIS_EXE = $nsis3Exe
Write-Host("##vso[task.setvariable variable=NSIS_EXE;]$nsis3Exe")

if ($justInclude -eq "no") {
    $args = ''

    if ($arguments -notcontains "/V") {
        if ($env:Debug -eq "true") {
            $args += "/V4 "
        }
        if ($env:Debug -eq "false") {
            $args += "/V1 "
        }
    }
    $args += $arguments + ' "' + $scriptFile + '"'

    Write-Host("Executing nsis $nsis3Exe with args: $args")

    Invoke-VstsTool -FileName $nsis3Exe -Arguments $args -RequireExitCodeZero
}
else {
    Write-Host("Including nsis in variable NSIS_EXE: $nsis3Exe")
}
