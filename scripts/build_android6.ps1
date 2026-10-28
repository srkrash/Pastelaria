param(
    [ValidateSet('prepare', 'get', 'analyze', 'test', 'build')]
    [string]$Action = 'build'
)
$ErrorActionPreference = 'Stop'
$compatRepository = Split-Path $PSScriptRoot -Parent
$compatSdk = Join-Path $compatRepository 'tools\flutter-3.32.8'
$compatProject = Join-Path $compatRepository 'tools\android6-build'
$compatLock = Join-Path $PSScriptRoot 'android6\pubspec.lock'

if ($Action -eq 'prepare') {
    New-Item -ItemType Directory -Path $compatProject -Force | Out-Null
    # Copy only sources/assets, never databases, credentials or modern build caches.
    foreach ($relative in @('lib', 'assets', 'test', 'android\app\src', 'android\gradle\wrapper')) {
        $source = Join-Path (Join-Path $compatRepository 'pastelaria_app') $relative
        $destination = Join-Path $compatProject $relative
        foreach ($file in Get-ChildItem -LiteralPath $source -Recurse -File) {
            $target = Join-Path $destination $file.FullName.Substring($source.Length + 1)
            New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        }
    }
    foreach ($relative in @('pubspec.yaml', 'analysis_options.yaml', 'android\app\build.gradle',
            'android\build.gradle', 'android\settings.gradle', 'android\gradle.properties',
            'android\gradlew', 'android\gradlew.bat')) {
        $source = Join-Path (Join-Path $compatRepository 'pastelaria_app') $relative
        $target = Join-Path $compatProject $relative
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    $gradlePath = Join-Path $compatProject 'android\app\build.gradle'
    $gradleSource = Get-Content -LiteralPath $gradlePath -Raw
    if (-not $gradleSource.Contains('minSdk = 24')) { throw 'Confira o Android mínimo no código principal antes de preparar a variante.' }
    $gradleSource = $gradleSource.Replace('minSdk = 24', 'minSdk = 23')
    $gradleSource = $gradleSource.Replace('ndkVersion = flutter.ndkVersion', 'ndkVersion = "28.2.13676358"')
    $gradleSource = $gradleSource.Replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = 36')
    $gradleSource = $gradleSource.Replace('targetSdk = flutter.targetSdkVersion', 'targetSdk = 36')
    Set-Content -LiteralPath $gradlePath -Value $gradleSource -Encoding utf8
    # initialValue was introduced after Flutter 3.32; value has the same initial
    # selection behavior for this form. Keep this adaptation isolated.
    $configPath = Join-Path $compatProject 'lib\screens\config_screen.dart'
    $configSource = Get-Content -LiteralPath $configPath -Raw
    if (-not $configSource.Contains('initialValue: _role')) { throw 'Confira a seleção de papel antes de adaptar para Flutter 3.32.' }
    Set-Content -LiteralPath $configPath -Value $configSource.Replace('initialValue: _role', 'value: _role') -Encoding utf8
    $specPath = Join-Path $compatProject 'pubspec.yaml'
    $specSource = Get-Content -LiteralPath $specPath -Raw
    $specSource = [regex]::Replace($specSource, '(?m)^version: ([0-9.]+)\+([0-9]+)', 'version: $1-android6+$2')
    Set-Content -LiteralPath $specPath -Value $specSource -Encoding utf8
    if (Test-Path -LiteralPath $compatLock) { Copy-Item -LiteralPath $compatLock -Destination (Join-Path $compatProject 'pubspec.lock') -Force }
    Write-Output "Fontes preparadas em $compatProject; projeto/SDK atuais preservados."
    exit 0
}

if (-not (Test-Path -LiteralPath (Join-Path $compatProject 'pubspec.yaml'))) { throw 'Execute primeiro com -Action prepare.' }
if (-not (Test-Path -LiteralPath (Join-Path $compatSdk 'bin\flutter.bat'))) { throw 'Prepare o Flutter oficial 3.32.8 em tools/flutter-3.32.8.' }
$compatFileSystem = New-Object -ComObject Scripting.FileSystemObject
$compatSdkShort = $compatFileSystem.GetFolder($compatSdk).ShortPath
$compatProjectShort = $compatFileSystem.GetFolder($compatProject).ShortPath
$env:FLUTTER_ROOT = $compatSdkShort
$env:PATH = "$compatSdkShort\bin;$env:PATH"
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
if (Test-Path -LiteralPath 'C:\Program Files\Java\jdk-21.0.12') {
    $env:JAVA_HOME = 'C:\Program Files\Java\jdk-21.0.12'
    $env:GRADLE_OPTS = "-Dorg.gradle.java.home=`"$env:JAVA_HOME`""
}
$env:GIT_CONFIG_COUNT = '2'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = $compatSdk.Replace('\', '/')
$env:GIT_CONFIG_KEY_1 = 'safe.directory'
$env:GIT_CONFIG_VALUE_1 = $compatSdkShort.Replace('\', '/')
Push-Location $compatProjectShort
try {
    $compatArguments = switch ($Action) {
        'get' { @('pub', 'get') }
        'analyze' { @('analyze', '--no-pub') }
        'test' { @('test', '--no-pub') }
        'build' { @('build', 'apk', '--release', '--no-pub', '--target-platform=android-arm') }
    }
    & (Join-Path $compatSdkShort 'bin\flutter.bat') --no-version-check --suppress-analytics @compatArguments
    $compatExit = $LASTEXITCODE
} finally { Pop-Location }
if ($compatExit -eq 0 -and $Action -eq 'get') {
    New-Item -ItemType Directory -Path (Split-Path $compatLock -Parent) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $compatProject 'pubspec.lock') -Destination $compatLock -Force
}
exit $compatExit
