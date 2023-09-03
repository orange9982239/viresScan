function createHtmlReport(
	$networkScanReportPath,
	$diskVirusScanReportPath,
	$virusReportPath
) {
	if (-Not(Test-Path -path $virusReportPath)) {
		# 未中毒情況
		$networkScanReport = (Get-Content $networkScanReportPath | ConvertFrom-Csv)
		$diskVirusScanReport = (Get-Content $diskVirusScanReportPath | ConvertFrom-Csv)
		
		return "
		<pre>
		* 掃描$($networkScanReport.IP.Count)個IP，總共$($diskVirusScanReport.DiskUnc.Count)個磁碟，無中毒檔案，掃描報告附檔zip如下
		
		[IP]掃描結果
		</pre>
		<table border='1'>
		  <tr>
			<th>time</th>
			<th>Ip</th>
			<th>message</th>
		  </tr>
		  $($networkScanReport | ForEach-Object {"
			<tr>
				<td>$($_.time)</td>
				<td>$($_.Ip)</td>
				<td>$($_.message)</td>
			</tr>
		  "})
		</table>
	
		<pre>
	
		[Disk]掃描結果
		</pre>
		<table border='1'>
		  <tr>
			<th>time</th>
			<th>Ip</th>
			<th>DiskUnc</th>
			<th>message</th>
		  </tr>
		  $($diskVirusScanReport | ForEach-Object {"
			<tr>
				<td>$($_.time)</td>
				<td>$($_.Ip)</td>
				<td>$($_.DiskUnc)</td>
				<td>$($_.message)</td>
			</tr>
		  "})
		</table>
		<pre>
		[病毒]掃描結果
		---無中毒檔案---
		</pre>
		" -replace "    ",""
	} else {
		# 中毒情況
		$networkScanReport = (Get-Content $networkScanReportPath | ConvertFrom-Csv)
		$diskVirusScanReport = (Get-Content $diskVirusScanReportPath | ConvertFrom-Csv)
		$virusReport = (Get-Content $virusReportPath | ConvertFrom-Csv)
		
		return "
		<pre>
		* 掃描$($networkScanReport.IP.Count)個IP，總共$($diskVirusScanReport.DiskUnc.Count)個磁碟，中毒檔案$($virusReport.VirusPath.Count)個，掃描報告附檔zip如下
		
		[IP]掃描結果
		</pre>
		<table border='1'>
		  <tr>
			<th>time</th>
			<th>Ip</th>
			<th>message</th>
		  </tr>
		  $($networkScanReport | ForEach-Object {"
			<tr>
				<td>$($_.time)</td>
				<td>$($_.Ip)</td>
				<td>$($_.message)</td>
			</tr>
		  "})
		</table>
	
		<pre>
	
		[Disk]掃描結果
		</pre>
		<table border='1'>
		  <tr>
			<th>time</th>
			<th>Ip</th>
			<th>DiskUnc</th>
			<th>message</th>
		  </tr>
		  $($diskVirusScanReport | ForEach-Object {"
			<tr>
				<td>$($_.time)</td>
				<td>$($_.Ip)</td>
				<td>$($_.DiskUnc)</td>
				<td>$($_.message)</td>
			</tr>
		  "})
		</table>
		<pre>
		[病毒]掃描結果
		</pre>
		<table border='1'>
		  <tr>
			<th>time</th>
			<th>Ip</th>
			<th>DiskUnc</th>
			<th>VirusType</th>
			<th>VirusPath</th>
		  </tr>
		  $($virusReport | ForEach-Object {"
			<tr>
				<td>$($_.time)</td>
				<td>$($_.Ip)</td>
				<td>$($_.DiskUnc)</td>
				<td>$($_.VirusType)</td>
				<td>$($_.VirusPath)</td>
			</tr>
		  "})
		</table>
		" -replace "    ",""
	}
}