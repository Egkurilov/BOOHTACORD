param([Parameter(Mandatory=$true)][string]$Path)
$ErrorActionPreference = 'Stop'
$signature = Get-AuthenticodeSignature -LiteralPath $Path
if ($signature.Status -eq 'NotSigned') {
    @{status='unsigned'} | ConvertTo-Json -Compress
} elseif ($signature.Status -eq 'Valid') {
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fingerprint = ([BitConverter]::ToString($hash.ComputeHash($signature.SignerCertificate.RawData))).Replace('-', '').ToLowerInvariant()
        @{status='signed'; certificate_sha256=$fingerprint} | ConvertTo-Json -Compress
    } finally { $hash.Dispose() }
} else { throw 'Windows artifact has an invalid Authenticode signature.' }
