#run this first: netsh http add urlacl url=http://+:8000/ user=DOMAIN\user
Add-Type -AssemblyName System.Web
$Hso = New-Object Net.HttpListener
$Hso.Prefixes.Add("http://+:8000/")
$Hso.Start()
$BufSize = 16384
$Buf = new-object byte[] $BufSize
New-PSDrive -Name MyPowerShellSite -PSProvider FileSystem -Root $PWD.Path
While ($Hso.IsListening) {
    $HC = $Hso.GetContext()
    $HReq = $HC.Request
    $HRes = $HC.Response
	
    $localPath = Join-Path (Join-Path "MyPowerShellSite:" "http") ($HC.Request).RawUrl
    $fs = New-Object System.IO.FileStream((Get-Item $localPath), [System.IO.FileMode]::Open)
    $HRes.ContentType = [System.Web.MimeMapping]::GetMimeMapping($localPath)

    $readStart = 0
    if ("Range" -in $HReq.Headers.AllKeys)
    {
        $readStart = [Int64]($HReq.Headers["Range"] -replace "^bytes=([0-9]+).*","`$1")
        $fs.Seek($readStart, [System.IO.SeekOrigin]::Begin) | Out-Null
        $HRes.Headers.Add("Content-Range","bytes $($readStart)-$($fs.Length-1)/$($fs.Length)")
        $HRes.StatusCode = 206
    }

    $HRes.ContentLength64 = $fs.Length - $readStart

    Try
    {
        $readLen = 0
        Do
        {
            $readLen = $fs.Read($Buf, 0, $BufSize)
            $HRes.OutputStream.Write($Buf,0,$readLen)
        } 
        While ($readLen -gt 0)
    }
    Catch
    {
        Write-Host $_.Exception.Message
    }
    $fs.Close()
    $HRes.Close()
}
$Hso.Stop()
