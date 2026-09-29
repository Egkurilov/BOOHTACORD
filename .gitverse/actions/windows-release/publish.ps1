param(
  [Parameter(Mandatory = $true)][string]$Tag,
  [Parameter(Mandatory = $true)][string]$Commit,
  [Parameter(Mandatory = $true)][string]$Archive
)

$ErrorActionPreference = 'Stop'
if ($Tag -cnotmatch '^windows-v\d+\.\d+\.\d+$') { throw 'Invalid Windows release tag.' }
if ($Commit -notmatch '^[0-9a-f]{40}$') { throw 'Invalid release commit.' }
$token = [Environment]::GetEnvironmentVariable('RELEASE_API_KEY')
if ([string]::IsNullOrWhiteSpace($token)) { throw 'RELEASE_API_KEY is missing.' }
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$assetName = [IO.Path]::GetFileName($archivePath)
if ($assetName -cne "BOOHTACORD-$Tag-x64.zip") { throw 'Archive name does not match tag.' }
$assetSize = (Get-Item -LiteralPath $archivePath).Length
if ($assetSize -le 0 -or $assetSize -gt 95000000) { throw 'Invalid archive size.' }

Add-Type -AssemblyName System.Net.Http
$client = [Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromSeconds(90)
$client.DefaultRequestHeaders.Authorization =
  [Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $token)
$client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.gitverse.object+json;version=1')
$api = 'https://api.gitverse.ru/repos/egkurilov/BOOHTACORD'

function Send-ReleaseRequest {
  param([string]$Method, [string]$Uri, [string]$JsonBody, [string]$UploadPath)
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    $request = [Net.Http.HttpRequestMessage]::new([Net.Http.HttpMethod]::new($Method), [Uri]$Uri)
    $response = $null
    try {
      if ($JsonBody) {
        $request.Content = [Net.Http.StringContent]::new($JsonBody, [Text.Encoding]::UTF8, 'application/json')
      }
      if ($UploadPath) {
        $multipart = [Net.Http.MultipartFormDataContent]::new()
        $stream = [IO.File]::OpenRead($UploadPath)
        $multipart.Add([Net.Http.StreamContent]::new($stream), 'attachment', [IO.Path]::GetFileName($UploadPath))
        $request.Content = $multipart
      }
      $response = $client.SendAsync($request).GetAwaiter().GetResult()
      $status = [int]$response.StatusCode
      $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
      if (($status -eq 429 -or $status -ge 500) -and $attempt -lt 4) {
        Write-Host "GitVerse API returned $status; retry $attempt/4."
        Start-Sleep -Seconds (3 * $attempt)
        continue
      }
      return @{ Status = $status; Body = $body }
    } catch {
      if ($attempt -eq 4) {
        throw "GitVerse API $Method failed after four attempts: $($_.Exception.GetType().Name)"
      }
      Write-Host "GitVerse API transport failed; retry $attempt/4."
      Start-Sleep -Seconds (3 * $attempt)
    } finally {
      if ($response) { $response.Dispose() }
      $request.Dispose()
    }
  }
}

try {
  $release = Send-ReleaseRequest -Method GET -Uri "$api/releases/tags/$Tag"
  if ($release.Status -eq 404) {
    $payload = @{
      tag_name = $Tag
      target_commitish = $Commit
      name = "BOOHTACORD Windows $Tag"
      body = 'Сборка приложения BOOHTACORD для Windows x64. Включает актуальный общий Flutter-код Android и статистику отправителя в локальном предпросмотре экрана. Распакуйте архив целиком и запустите boohtacord_desktop.exe.'
      draft = $false
      prerelease = $false
    } | ConvertTo-Json -Compress
    $release = Send-ReleaseRequest -Method POST -Uri "$api/releases" -JsonBody $payload
    if ($release.Status -eq 409) {
      $release = Send-ReleaseRequest -Method GET -Uri "$api/releases/tags/$Tag"
    }
  }
  if ($release.Status -notin @(200, 201)) { throw "GitVerse release request returned HTTP $($release.Status)." }
  $releaseId = [long](ConvertFrom-Json -InputObject $release.Body).id
  if ($releaseId -le 0) { throw 'GitVerse release response has no ID.' }
  $assetsUri = "$api/releases/$releaseId/assets"
  $assets = Send-ReleaseRequest -Method GET -Uri $assetsUri
  if ($assets.Status -ne 200) { throw "GitVerse asset list returned HTTP $($assets.Status)." }
  $existing = @(ConvertFrom-Json -InputObject $assets.Body | Where-Object { $_.name -ceq $assetName })
  if ($existing.Count -gt 0) {
    if ([long]$existing[0].size -ne $assetSize) { throw 'Existing release asset size differs.' }
    Write-Host "Windows release asset already present: $assetName ($assetSize bytes)."
  } else {
    $encodedName = [Uri]::EscapeDataString($assetName)
    $upload = Send-ReleaseRequest -Method POST -Uri "$assetsUri`?name=$encodedName" -UploadPath $archivePath
    if ($upload.Status -ne 201) { throw "GitVerse asset upload returned HTTP $($upload.Status)." }
    $uploaded = ConvertFrom-Json -InputObject $upload.Body
    if ($uploaded.name -cne $assetName -or [long]$uploaded.size -ne $assetSize) {
      throw 'GitVerse asset response does not match the archive.'
    }
    Write-Host "Published Windows release asset: $assetName ($assetSize bytes)."
  }
} finally {
  $client.Dispose()
}
