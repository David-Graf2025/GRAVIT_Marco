
$inp = "protocol=https`nhost=github.com`nusername=David-Graf2025`n`n"
$out = $inp | git -c credential.helper=wincred credential fill 2>&1
$pw = [string]($out | Select-String "^password=") -replace "^password=",""
Write-Host "Token Laenge: $($pw.Trim().Length)"

$req = [System.Net.HttpWebRequest]::Create("https://api.github.com/user/repos")
$req.Method = "POST"
$req.Headers.Add("Authorization", "token $($pw.Trim())")
$req.UserAgent = "PowerShell/5.1"
$req.ContentType = "application/json"
$body = '{"name":"GRAVIT_Marco","private":false,"description":"gravit_fresh Flutter project"}'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$req.ContentLength = $bytes.Length
$s = $req.GetRequestStream()
$s.Write($bytes, 0, $bytes.Length)
$s.Close()

try {
    $resp = $req.GetResponse()
    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
    $json = $sr.ReadToEnd() | ConvertFrom-Json
    Write-Host "SUCCESS: $($json.html_url)"
} catch [System.Net.WebException] {
    $errStream = $_.Exception.Response.GetResponseStream()
    if ($errStream) {
        $errSr = New-Object System.IO.StreamReader($errStream)
        Write-Host "HTTP Fehler: $($errSr.ReadToEnd())"
    } else {
        Write-Host "Netzwerkfehler: $($_.Exception.Message)"
    }
} catch {
    Write-Host "Allgemeiner Fehler: $($_.Exception.Message)"
}
