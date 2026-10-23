param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArguments
)
$ErrorActionPreference = 'Stop'
$flutterSdkRoot = if ($env:FLUTTER_ROOT) { $env:FLUTTER_ROOT } else { 'D:\Dev\Flutter\flutter' }
$flutterDart = Join-Path $flutterSdkRoot 'bin\cache\dart-sdk\bin\dart.exe'
$flutterSnapshot = Join-Path $flutterSdkRoot 'bin\cache\flutter_tools.snapshot'
if (-not (Test-Path -LiteralPath $flutterDart)) { throw 'Defina FLUTTER_ROOT para o SDK Flutter instalado.' }
$env:FLUTTER_ROOT = $flutterSdkRoot
$env:PATH = "$flutterSdkRoot\bin;$env:PATH"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
if (Test-Path -LiteralPath 'C:\Program Files\Java\jdk-21.0.12') {
    $env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.12'
    $env:GRADLE_OPTS = "-Dorg.gradle.java.home=`"$env:JAVA_HOME`""
}
# Escopo deste processo: não modifica a configuração global do Git.
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = $flutterSdkRoot.Replace('\', '/')
Push-Location (Join-Path $PSScriptRoot '..\pastelaria_app')
try {
    & $flutterDart $flutterSnapshot --no-version-check --suppress-analytics @FlutterArguments
    $flutterExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $flutterExitCode
