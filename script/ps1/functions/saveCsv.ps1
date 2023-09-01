function saveCsv($outputFilePath,[PSCustomObject]$data,$isPrint=$false) {
    # 印出結果
    if($isPrint -eq $true){
        $data | Format-Table 
    }
    
    # 存csv
    if (Test-Path $outputFilePath) {
        Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
        # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
    } else {
        New-Item -Path $outputFilePath -ItemType File -Force
        Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
        # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 
    }
}

# $data1 = [PSCustomObject]@{
#     testcol1="testcal1val1"
#     testcol2="testcal2val1"
# }
# saveCsv -outputFilePath "C:\powershell\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $data1


# $data2 = [PSCustomObject]@{
#     testcol1="testcal1val2"
#     testcol2="testcal2val2"
# }
# saveCsv -outputFilePath "C:\powershell\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $data1

function saveArrayToCsv($outputFilePath,[PSCustomObject[]]$datas,$isPrint=$false) {
    # 印出結果
    foreach ($data in $datas) {
        if($isPrint -eq $true){
            $data | Format-Table 
        }
        
        # 存csv
        if (Test-Path $outputFilePath) {
            Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
            # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 -Append -Force
        } else {
            New-Item -Path $outputFilePath -ItemType File -Force
            Export-Csv -InputObject $data -Path $outputFilePath -NoTypeInformation -Encoding UTF8
            # $data | Export-Csv $outputFilePath -NoTypeInformation -Encoding UTF8 
        }
    }
}
# $datas = @(
#     [PSCustomObject]@{
#         testcol1="testcal1val1"
#         testcol2="testcal2val1"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val2"
#         testcol2="testcal2val2"
#     },
#     [PSCustomObject]@{
#         testcol1="testcal1val3"
#         testcol2="testcal2val3"
#     }
# )

# saveArrayToCsv -outputFilePath "C:\test$((Get-Date).ToString("yyyyMMdd")).csv" -data $datas