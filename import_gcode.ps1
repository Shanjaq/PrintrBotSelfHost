Param
(
	[Parameter(Mandatory=$true)]
	[string]$projectName, #some_project_name
	[Parameter(Mandatory=$true)]
	[string]$gcodeFileName, #some_gcode_file.gcode
	[Parameter(Mandatory=$true)]
	[string]$hostAddress, #some_address:8000
	[string]$printerAddress = "" #some_printer_address
)

$file_part_a = "project_part_a"
$file_part_b = "project_part_b"
$file_part_c = "project_part_c"


function New-RandomString ($count) {
	$c = $null
	for ($i = 1; $i -le $count; $i++) {
		$a = Get-Random -Minimum 1 -Maximum 4
		switch ($a) {
			1 {$b = Get-Random -Minimum 48 -Maximum 58}
			2 {$b = Get-Random -Minimum 65 -Maximum 91}
			3 {$b = Get-Random -Minimum 97 -Maximum 123}
		}
		[string]$c += [char]$b
	}
	$c
}


function Build-Project ($prjName, $fileName, $hostAddr)
{
	$projectId = New-RandomString -count 8
	$some_id = New-RandomString -count 32

	$ostream = [System.Io.File]::OpenWrite("http\projects\$($projectId.ToUpper())")
	$bytes = [System.IO.File]::ReadAllBytes($file_part_a)
	$file_part_a_size = $bytes.Count
	$tmp = "$($some_id.ToUpper())$($projectId)$([char]0)$([char]1)$($prjName.ToUpper())$("$([char]0)" * (31-$prjName.Length))"
	for ($i = 0; $i -le $tmp.Length; $i++)
	{
		$bytes[$i] = $tmp[$i]
	}
	$ostream.Write($bytes, 0, $file_part_a_size)

	#char[8]+0x00+"20"+"fileName+pad[32]+http://hostAddr+generated_gcode_file_name+pad[256]"
	$file_part_b_size = 299
	$bytes = New-Object byte[] $file_part_b_size
	$job_name = New-RandomString -count 8
	for ($i = 0; $i -le 7; $i++)
	{
		$bytes[$i] = $job_name[$i]
	}
	$bytes[9] = 50
	$bytes[10] = 48
	$gcoFileName = $gcodeFileName -replace ".gcode$", ".gco"
	for ($i = 0; $i -le $gcoFileName.Length; $i++)
	{
		$bytes[11+$i] = $gcoFileName[$i]
	}
	$gcode_file_address = "http://$($hostAddr)/gcode/$($fileName).gco"
	for ($i = 0; $i -le $gcode_file_address.Length; $i++)
	{
		$bytes[43+$i] = $gcode_file_address[$i]
	}
	$ostream.Write($bytes, 0, $file_part_b_size)

	$bytes = [System.IO.File]::ReadAllBytes($file_part_c)
	$file_part_c_size = $bytes.Count
	$ostream.Write($bytes, 0, $file_part_c_size)

	$ostream.close()

	$projectId.ToUpper()
}


function Convert-GCode ($fileName)
{
	$some_id = New-RandomString -count 32
	$ostream = [System.Io.File]::OpenWrite("http\gcode\$($some_id.ToLower()).tmp")
	$line_count = 3
	#$ostream.Write(([byte[]][char[]]("$($_)`r`n")), 0, ($_.Length+2))

	Get-Content $fileName | ForEach-Object {
		#replacements
		$gcode_line = ($_ -replace "^M104\s+S([0-9]+)", "M100 ({he1st:`$1}); Was: $&")
		$gcode_line = ($gcode_line -replace "^M109\s+S([0-9]+)","M100 ({he1st:`$1}); Was: $&`r`nM101 ({he1at:t}); wait for At Temp")
		$gcode_line = ($gcode_line -replace "M107","M100 ({out4:0}); Was: M107")
		$gcode_line = ($gcode_line -replace "^M140\s+S([0-9]+)","M100 ({he3st:`$1}); Was: $&")
		$gcode_line = ($gcode_line -replace "^M106\s+S([0-9]+)","M100 ({out4:1.000}); Was: $&")
		$gcode_line = ($gcode_line -replace [regex]::escape("\\"),"\")
		$gcode_line = ($gcode_line -replace "E(?=-?[0-9]+\.?[0-9]*$)","A")
		$gcode_line = "$($gcode_line)`r`n"
		$line_count++
		$ostream.Write(([byte[]][char[]]($gcode_line)), 0, ($gcode_line.Length))
	}
	$end_gcode = ";Retract the filament`r`nG92 E1`r`nG1 E-1 F300`r`nG28 X0 Y0`r`nM84`r`nM2 ; Completed job, reset state`r`n"
	$ostream.Write(([byte[]][char[]]($end_gcode)), 0, ($end_gcode.Length))

	$ostream.close()
	$header = Get-Content -Raw -Path gcode_header_template.json | ConvertFrom-Json
	$header.lines = $line_count
	@(";$($header | ConvertTo-Json)" -replace "`r|`n|\s+", "") +  (Get-Content "http\gcode\$($some_id.ToLower()).tmp") | Set-Content "http\gcode\$($some_id.ToLower()).gco"
	Remove-Item "http\gcode\$($some_id.ToLower()).tmp"
	$some_id
}


$gcode_file_id = Convert-GCode -fileName $gcodeFileName
$project_file_name = Build-Project -prjName $projectName -fileName $gcode_file_id -hostAddr $hostAddress


$restoreColor = [console]::ForegroundColor
if ($printerAddress -ne "")
{
	Write-Host "send this request to download the project onto the printer:"
	[console]::ForegroundColor = "Green"
	Write-Host "http://$($printerAddress)/fetch?id=$($project_file_name)&url=http://$($hostAddress)/projects/$($project_file_name)&type=project"
}
else
{
	[console]::ForegroundColor = "Yellow"
	Write-Host "printer_ip_address must be filled in before sending this request to download the project onto the printer:"
	[console]::ForegroundColor = "Green"
	Write-Host "http://printer_ip_address/fetch?id=$($project_file_name)&url=http://$($hostAddress)/projects/$($project_file_name)&type=project"
}
[console]::ForegroundColor = $restoreColor
