### (暫緩)多線程寫入會導致漏資料，需要先寫入記憶體或是DB來解決
### 需使用powershell7
### cmd `pwsh -ExecutionPolicy Bypass -File C:\script\ps1\f-secure-scean-multi-threat.ps1`
Import-Module C:\script\ps1\functions\saveCsv.ps1
Import-Module C:\script\ps1\functions\alert.ps1
Import-Module C:\script\ps1\functions\virusReportReader.ps1

$outputFolderPath = "C:\script\log\f-secure-scean_log\$((Get-Date).ToString("yyyyMMdd"))"    # 放csv簡述報告及所有HTML報告dir
$credentials = (Get-Content -Raw -Path "C:\script\ps1\config\credentialsEncripted.json" | ConvertFrom-Json) | ForEach-Object {
    New-Object System.Management.Automation.PSCredential (
        $_.account,
        ($_.passwordEncripted | ConvertTo-SecureString)
    )
}

# 取得 IP Array
# $IPRangeArray = $(
#     ((1..255) | ForEach-Object { "10.10.24.$($_)" })
# )
$IPRangeArray = $(
    ((1..255) | ForEach-Object { "192.168.13.$($_)" })
)
# $IPRangeArray = $(
#     ((1..100) | ForEach-Object { "10.10.24.$($_)" });
#     ((101..255) | ForEach-Object { "10.10.25.$($_)" })
# )
# $IPRangeArray = $(
#     ((146..146) | ForEach-Object { "10.10.24.$($_)" })
# )

# add env
$env:Path += ';C:\Program Files (x86)\F-Secure\Server Security\'

# 全網段掃描結果 networkScanReport.csv
# 硬碟清單 diskScanReport.csv
$networkScanReportPath = "$($outputFolderPath)\networkScanReport.csv"
$diskScanReportPath = "$($outputFolderPath)\diskScanReport.csv"

$IPRangeArray | ForEach-Object -Parallel {
    Import-Module C:\script\ps1\functions\saveCsv.ps1
    Import-Module C:\script\ps1\functions\alert.ps1
    Import-Module C:\script\ps1\functions\virusReportReader.ps1
    $IP = $_
    $networkScanReportPath = $using:networkScanReportPath
    $credentials = $using:credentials
    $networkScanReportPath = $using:networkScanReportPath
    $diskScanReportPath = $using:diskScanReportPath

    Write-Output "開始掃描網段 $IP"
    
    # test ping 
    if ((Test-Connection $IP -Count 1 -Quiet) -eq $false) {
        # 產報告
        $data = [PSCustomObject]@{
            time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
            Ip = $IP
            message = "ping不通"
        }
        saveCsv -outputFilePath $networkScanReportPath -data $data
    
        # ping不通就換下一個IP
        return    
    }
    
    # test windows login
    foreach ($credential in $credentials) {
        try {
            # 遠端作業
            $PhysicalDiskUNCs = (
                Invoke-Command -ComputerName $IP -ScriptBlock {
                    Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" 
                } -credential $credential -ErrorAction Stop
            ) | ForEach-Object {"\\$($IP)\$($_.DeviceID.replace(':','').ToLower())$"}
    
            foreach ($DiskUnc in $PhysicalDiskUNCs) {
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    Ip = $IP
                    ScanType = "smb"
                    CredentialIndex = $credentials.IndexOf($credential)
                    DiskUnc = $DiskUnc
                }
                saveCsv -outputFilePath $diskScanReportPath -data $data
            }
            
            $data = [PSCustomObject]@{
                time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                Ip = $IP
                message = "WinRM登入成功"
            }
            saveCsv -outputFilePath $networkScanReportPath -data $data
    
            # 登入成功並完成掃描就換下一個IP
            return
        } catch {
            if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
                $data = [PSCustomObject]@{
                    time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
                    Ip = $IP
                    message = "嘗試了所有的credential仍無法登入WinRM"
                }
                saveCsv -outputFilePath $networkScanReportPath -data $data
                return
            }
        }
    }
    # linux test login
    # foreach ($credential in $credentials) {
    #     try {
    #         # 用sshfs直接mount?
    #         $data = [PSCustomObject]@{
    #             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #             Ip = $IP
    #             ScanType = "sftp"
    #             CredentialIndex = $credentials.IndexOf($credential)
    #             DiskUnc = "====linuxSFTPDiskUNC====="
    #         }
    #         # 存csv
    #         saveCsv -outputFilePath $diskScanReportPath -data $data
    
    #         $data = [PSCustomObject]@{
    #             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #             Ip = $IP
    #             message = "SSH登入成功"
    #         }
    #         saveCsv -outputFilePath $networkScanReportPath -data $data
    #         # 登入成功並完成掃描就換下一個IP
    #         break
    #     } catch {
    #         if(($credentials.IndexOf($credential)+1) -eq $credentials.Count){
    #             # 產報告
    #             $data = [PSCustomObject]@{
    #                 time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
    #                 Ip = $IP
    #                 message = "嘗試了所有的credential仍無法登入ssh"
    #             }
    #             # 存csv
    #             saveCsv -outputFilePath $networkScanReportPath -data $data
    #         }
    #     }
    # }
} -ThrottleLimit 10 -UseNewRunspace

# 列出各個DiskUnc掃毒結果(只顯示中毒數量) diskVirusScanReport_yyyymmdd.csv
# 列出所有中毒檔案路徑 VirusReport_yyyymmdd.csv

# $diskVirusScanReportPath = "$($outputFolderPath)\diskVirusScanReport.csv"
# $virusReportPath = "$($outputFolderPath)\VirusReport.csv"

# $diskScanReport = (Get-Content $diskScanReportPath | ConvertFrom-Csv)
# $diskScanReport | ForEach-Object -Parallel {
#     Import-Module C:\script\ps1\functions\saveCsv.ps1
#     Import-Module C:\script\ps1\functions\alert.ps1
#     Import-Module C:\script\ps1\functions\virusReportReader.ps1
#     $disk = $_
#     $credentials = $using:credentials
#     $diskVirusScanReportPath = $using:diskVirusScanReportPath
#     $diskVirusScanReportPath = $using:diskVirusScanReportPath

#     Write-Output "開始掃描磁碟: $($disk.DiskUnc)"

#     # 連線smb(根據CredentialIndex取出特定Credential)
#     $credential = $credentials[$disk.CredentialIndex]
#     if (-Not (Test-Path $disk.DiskUnc)){
#         net use $($disk.DiskUnc) /user:$($credential.GetNetworkCredential().username) $($credential.GetNetworkCredential().password)
#     }
    
#     # 掃毒smb路徑並存檔到C:\script\log\f-secure-scean_log\yyyymmdd\scan_log_127.0.0.1_c$.html
#     $reportFilePath = "$($outputFolderPath)\scan_log_$($disk.Ip)_$($disk.DiskUnc.substring($disk.DiskUnc.Length -2)).html"
#     fsscan $($disk.DiskUnc) /report=$reportFilePath
    
#     # 中毒報告取回資料
#     $VirusInReport = (virusReportReader $(Get-Content -path $reportFilePath -raw))

#     # 列出各個DiskUnc掃毒結果(只顯示中毒數量)
#     if ($VirusInReport.Count -eq 0) {
#         $data = [PSCustomObject]@{
#             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
#             Ip = $disk.Ip
#             DiskUnc = $disk.DiskUnc
#             message = "沒有中毒"
#         }
#         saveCsv -outputFilePath $diskVirusScanReportPath -data $data
#     } else {
#         # 補個mail告警

#         $data = [PSCustomObject]@{
#             time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
#             Ip = $disk.Ip
#             DiskUnc = $disk.DiskUnc
#             message = "中了$($VirusInReport.Count)個毒"
#         }
#         saveCsv -outputFilePath $diskVirusScanReportPath -data $data

#         # 列出所有中毒檔案路徑
#         $VirusInReport | ForEach-Object {
#             $data = [PSCustomObject]@{
#                 time = $(Get-Date -Format "yyyy/MM/dd HH:mm:ss")
#                 Ip = $disk.Ip
#                 DiskUnc = $disk.DiskUnc
#                 VirusType = $_.type
#                 VirusPath = $_.path
#             }
#             saveCsv -outputFilePath $virusReportPath -data $data
#         }
#     }
# } -ThrottleLimit 5

# # 壓縮資料夾成zip檔案
# $outputFolderZipFilePath = "$($outputFolderPath).zip"
# Compress-Archive -Path $outputFolderPath -DestinationPath $outputFolderZipFilePath -Force

# # 寄信+zip
# $networkScanReport = (Get-Content $networkScanReportPath | ConvertFrom-Csv)
# # $diskScanReport = (Get-Content $diskScanReportPath | ConvertFrom-Csv)
# $diskVirusScanReport = (Get-Content $diskVirusScanReportPath | ConvertFrom-Csv)
# $MailBodyHtml = ""
# if (-Not(Test-Path -path $virusReportPath)) {
#     $MailBodyHtml = "
#     <pre>
#     掃描$($networkScanReport.IP.Count)台，總共$($diskVirusScanReport.DiskUnc.Count)個磁碟，無中毒檔案，掃描報告附檔zip如下
    
#     [IP] 清單
#     $($networkScanReport.IP -join "`r`n")
    
#     [Disk] 清單
#     $($diskVirusScanReport.DiskUnc -join "`r`n")
#     </pre>
#     "
# } else {
#     $virusReport = (Get-Content $virusReportPath | ConvertFrom-Csv)
    
#     $MailBodyHtml = "
#     <pre>
#     掃描$($networkScanReport.IP.Count)台，總共$($diskVirusScanReport.DiskUnc.Count)個磁碟，中毒檔案$($virusReport.VirusPath.Count)個，掃描報告附檔zip如下
    
#     [IP] 清單
#     $($networkScanReport.IP -join "`r`n")
    
#     [Disk] 清單
#     $($diskVirusScanReport.DiskUnc -join "`r`n")
    
#     [病毒] 清單
#     $($virusReport.VirusPath -join "`r`n")
#     </pre>
#     "
# }

# $EmailParams = @{
#     To          = "ritchieliou@gamania.com"
#     # Cc          = $Cc
#     From        = "fsecureScan@gamania.com"
#     Subject     = "[ITGT] 掃毒報告_$((Get-Date).ToString("yyyyMMdd"))"
#     Body        = $MailBodyHtml
#     BodyAsHtml  = $true
#     Priority    = "High"
#     SMTPServer  = "192.168.100.229"
#     Port        = 25
#     Encoding    = 'UTF8'
#     Attachments = $outputFolderZipFilePath
# }
# Send-MailMessage @EmailParams
# # 刪除zip檔案
# Remove-Item -Path $outputFolderZipFilePath