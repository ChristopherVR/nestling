param(
    [Parameter(Mandatory = $true)][string]$Device,
    [Parameter(Mandatory = $true)][string]$Camera,
    [int]$Seconds = 90,
    [switch]$RequireSound,
    [string]$Flutter = 'flutter',
    [string]$AndroidSdk = "$env:LOCALAPPDATA/Android/Sdk"
)
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $defines = @("--dart-define=NANIT_TEST_IP=$Camera", "--dart-define=ALERT_BACKGROUND_SECONDS=$Seconds")
    if ($RequireSound) { $defines += '--dart-define=ALERT_REQUIRE_SOUND=true' }
    # Prebuild is essential: without an APK Flutter can infer the production
    # namespace as the test identity before it sees the flavor's application ID.
    & $Flutter build apk --debug --flavor cameraTest --target integration_test/local_alerts_live_test.dart @defines
    if ($LASTEXITCODE -ne 0) { throw 'Test APK build failed; no deployment attempted.' }
    $apk = (Resolve-Path 'build/app/outputs/flutter-apk/app-cameratest-debug.apk').Path
    $aapt = Get-ChildItem -LiteralPath "$AndroidSdk/build-tools" -Directory |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'aapt.exe' } |
        Where-Object { Test-Path -LiteralPath $_ } |
        Select-Object -First 1
    if (!$aapt) { throw 'aapt is required to verify the test APK identity.' }
    $metadata = & $aapt dump badging $apk
    if ($LASTEXITCODE -ne 0 -or !($metadata -match "^package: name='com\.babyapp\.baby_app\.camera_test' ")) {
        throw 'Unexpected APK identity; refusing deployment.'
    }
    # No automatic removal, even when integration-test cleanup misidentifies a package.
    & $Flutter test integration_test/local_alerts_live_test.dart -d $Device --flavor cameraTest --no-uninstall @defines
    if ($LASTEXITCODE -ne 0) { throw 'Camera integration test failed.' }
} finally {
    Pop-Location
}
