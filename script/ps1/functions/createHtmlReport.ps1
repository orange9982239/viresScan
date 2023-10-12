function createHtmlReport(
	$pingTestPath,
	$loginTestPath,
	$antiVirusCheckPath,
	$diskToBeScanPath,
	$diskIsScanedPath,
	$diskListScanReportPath,
	$virusReportPath
) {
	# 取出掃毒引擎版本號
	## 取出任一個磁碟的掃毒報告
	$outputFolderPath = (ls $pingTestPath).Directory.FullName
	$fsecureReportfiles = ([Array](ls $outputFolderPath | Where-Object { $_.Extension -eq ".html"})).FullName
	
	$fsecureScanEnginData = $()
	if ($fsecureReportfile.Count -gt 0) {
		## 使用XPath取出掃毒引擎版本號
		$xml = [xml]$(Get-Content -path $($fsecureReportfiles[0]) -raw -Encoding UTF8)  # 將 HTML 轉換為XML
		$fsecureScanEnginData = [Array]($xml | Select-Xml "//ul[@class='list_engines']/li") | ForEach-Object {$_.Node.'#text'}
	}
	return "
	<html xmlns='http://www.w3.org/1999/xhtml'>
	* 掃描結果
	<table border='1'>
		<tr>
			<th>掃瞄(IP)數</th>
			<th>可登入(PC)數</th>
			<th>未安裝防毒(PC)數</th>
			<th>有安裝防毒(PC)數</th>
			<th>總(硬碟)數</th>
			<th>掃毒完成(硬碟)數</th>
			<th>(中毒檔案)數</th>
		</tr>
		<tr>
			<td>$(([Array](Get-Content $pingTestPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count)</td>
			<td>$(([Array](Get-Content $loginTestPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.loginResult -eq 1})).Count)</td>
			<td>$(([Array](Get-Content $antiVirusCheckPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.hasAntiVirus -eq 0})).Count)</td>
			<td>$(([Array](Get-Content $antiVirusCheckPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.hasAntiVirus -eq 1})).Count)</td>
			<td>$(if (Test-Path -path $diskToBeScanPath) {([Array](Get-Content $diskToBeScanPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count} else {0})</td>
			<td>$(if (Test-Path -path $diskListScanReportPath) {([Array](Get-Content $diskListScanReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count} else {0})</td>
			<td>$(if (Test-Path -path $virusReportPath) {([Array](Get-Content $virusReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count} else {0})</td>
		</tr>
	</table>

	* 不可登入PC IP清單
	<ul>$([Array](Get-Content $loginTestPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.loginResult -eq 0}) | ForEach-Object {"`n  <li>$($_.ip)</li>"})
	</ul>

	* 防毒引擎資訊
	<ul>$(if ($fsecureScanEnginData.Count -gt 0) {$fsecureScanEnginData | ForEach-Object {"`n  <li>$($_)</li>"}})
	</ul>
	
	$(
		if (Test-Path -path $virusReportPath) {
			$virusReport = [Array](Get-Content $virusReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)
			"
			* 中毒清單
			<table border='1'>
				<tr>
					<th>病毒名稱</th>
					<th>病毒檔案路徑</th>
				</tr>
				$($virusReport | ForEach-Object {
					"<tr>
						<td>$($_.virusName)</td>
						<td>$($_.virusPath)</td>
					</tr>"
				})
			</table>
			"
		}
	)
	</html>
	" -replace "    ",""
}

function createHtmlLinuxReport(
	$pingTestPath,
	$loginTestPath,
	$antiVirusCheckPath,
	$diskIsScanedPath,
	$diskListScanReportPath,
	$virusReportPath
) {
	# 取出掃毒引擎版本號
	## 取出任一個磁碟的掃毒報告
	$outputFolderPath = (ls $pingTestPath).Directory.FullName
	$fsecureReportfiles = [Array](ls $outputFolderPath | Where-Object { $_.Extension -eq ".html"}).FullName

	$fsecureScanEnginData = $()
	if ($fsecureReportfile.Count -gt 0) {
		## 使用XPath取出掃毒引擎版本號
		$xml = [xml]$(Get-Content -path $($fsecureReportfiles[0]) -raw -Encoding UTF8)  # 將 HTML 轉換為XML
		$fsecureScanEnginData = [Array]($xml | Select-Xml "//ul[@class='list_engines']/li") | ForEach-Object {$_.Node.'#text'}
	}

	return "
	<html xmlns='http://www.w3.org/1999/xhtml'>
	* 掃描結果
	<table border='1'>
		<tr>
			<th>掃瞄(IP)數</th>
			<th>可登入(PC)數</th>
			<th>未安裝防毒(PC)數</th>
			<th>有安裝防毒(PC)數</th>
			<th>掃毒完成(硬碟)數</th>
			<th>(中毒檔案)數</th>
		</tr>
		<tr>
			<td>$(([Array](Get-Content $pingTestPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count)</td>
			<td>$(([Array](Get-Content $loginTestPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.loginResult -eq 1})).Count)</td>
			<td>$(([Array](Get-Content $antiVirusCheckPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.hasAntiVirus -eq 0})).Count)</td>
			<td>$(([Array](Get-Content $antiVirusCheckPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.hasAntiVirus -eq 1})).Count)</td>
			<td>$(if (Test-Path -path $diskListScanReportPath) {([Array](Get-Content $diskListScanReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count} else {0})</td>
			<td>$(if (Test-Path -path $virusReportPath) {([Array](Get-Content $virusReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)).Count} else {0})</td>
		</tr>
	</table>

	* 不可登入PC IP清單
	<ul>$([Array](Get-Content $loginTestPath -raw -Encoding UTF8 | ConvertFrom-Csv | Where-Object {$_.loginResult -eq 0}) | ForEach-Object {"`n  <li>$($_.ip)</li>"})
	</ul>

	* 防毒引擎資訊
	<ul>$(if ($fsecureScanEnginData.Count -gt 0) {$fsecureScanEnginData | ForEach-Object {"`n  <li>$($_)</li>"}})
	</ul>
	
	$(
		if (Test-Path -path $virusReportPath) {
			$virusReport = [Array](Get-Content $virusReportPath -raw -Encoding UTF8 | ConvertFrom-Csv)
			"
			* 中毒清單
			<table border='1'>
				<tr>
					<th>病毒名稱</th>
					<th>病毒檔案路徑</th>
				</tr>
				$($virusReport | ForEach-Object {
					"<tr>
						<td>$($_.virusName)</td>
						<td>$($_.virusPath)</td>
					</tr>"
				})
			</table>
			"
		}
	)
	</html>
	" -replace "    ",""
}