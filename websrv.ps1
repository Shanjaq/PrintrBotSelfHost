#run this first: netsh http add urlacl url=http://+:8000/ user=DOMAIN\user
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
	$fs = New-Object System.IO.FileStream((Get-Item ((Join-Path (Join-Path $Pwd "http") ($HC.Request).RawUrl))), [System.IO.FileMode]::Open)
	
	$readStart = 0
	if ("Range" -in $HReq.Headers.AllKeys)
	{
		$readStart = [Int64]($HReq.Headers["Range"] -replace "^bytes=([0-9]+).*","`$1")
		$fs.Seek($readStart, [System.IO.SeekOrigin]::Begin) | Out-Null
		$HRes.Headers.Add("Content-Range","bytes $($readStart)-$($fs.Length-1)/$($fs.Length)")
		$HRes.StatusCode = 206;
	}

	$HRes.Headers.Add("Content-Type","application/octet-stream")
	$HRes.ContentLength64 = $fs.Length - $readStart
	$readLen = $fs.Read($Buf, 0, $BufSize)
	
	Try
	{
		While ($readLen -gt 0)
		{
			$HRes.OutputStream.Write($Buf,0,$readLen)
			$readLen = $fs.Read($Buf, 0, $BufSize)
			$readStart += $readLen
		}
	}
	Catch
	{
		Write-Host $_.Exception.Message
	}
	$fs.Close()
    $HRes.Close()
}
$Hso.Stop()