function virusReportReader($HtmlContent) {
    $virus = New-Object System.Collections.Generic.List[PSCustomObject]
    if ($HtmlContent.Contains("No harmful items found") -or $HtmlContent.Contains("未發現有害項目")) {
        # 沒中毒
        return $virus
    }else{
        # 中毒
        # 取出ClassName=infected的html string
        $html = new-object -ComObject HTMLFile                                                      # 建立com物件處理HTML
        $html.write([System.Text.Encoding]::Unicode.GetBytes($HtmlContent))                         # 寫入html文字
        $Htmlinfected = $html.getElementsByClassName('infected')|ForEach-Object{$_.innerHTML}       # 取出string

        # 取出中毒類別
        $patternCategory = '<A href="[^"]+">([^<]+)</A>'
        $categories = [regex]::Matches($Htmlinfected, $patternCategory) | ForEach-Object {
            $_.Groups[1].Value.Trim()
        }

        # 取出中毒檔案路徑
        $patternPath = '<LI>([^<]+)</LI>'
        $paths = [regex]::Matches($Htmlinfected, $patternPath) | ForEach-Object {
            $_.Groups[1].Value.Trim()
        }

        for ($i = 0; $i -lt $categories.Count; $i++) {
            $virus.Add(
                [PSCustomObject]@{
                    "type" = $categories[$i]
                    "path" = $paths[$i]
                }
            )
        }
        return $virus
    }
}

# $HtmlContent = @"
# <html lang="en">
#     <head>
#         <meta http-equiv="Content-Type" content="text/xhtml;charset=UTF-8"/>
#         <title>Scan report - F-Secure Server Security Premium</title>
#         <link rel="shortcut icon" href="file:///C:/ProgramData/F-Secure/latebound/customization/../100/Customization/mysa.ico"/>
#         <link rel="stylesheet" type="text/css" charset="utf-8" href="file:///C:/ProgramData/F-Secure/latebound/customization/scan_report.css"/>
#     </head>
#     <body>
#         <div class="section_title">
#             <h1 class="pagetitle">Scan report - F-Secure Server Security Premium</h1>
#             <h4>Saturday, June 24, 2023 5:54:14 PM - 5:54:19 PM (UTC+08:00)</h4>
#             <p>Scan type: Malware scan</p>
#             <div class="targets">
#                 <h4>Targets:</h4>
#                 <ul class="list_targets">
#                     <li>C:\Users\Administrator\Desktop\eicar</li>
#                 </ul>
#             </div>
#             <div class="exclusions">
#                 <h4>Exclusions:</h4>
#                 <ul class="list_exclusions">
#                     <li>C:\Program Files (x86)\F-Secure\Management Server 5\data\solr\data</li>
#                 </ul>
#             </div>
#         </div>
#         <div class="section_results">
#             <h2>Results</h2>
#             <ul class="result_data">
#                 <li class="result_inf">Harmful items found: 4</li>
#                 <li>Items scanned: 4</li>
#             </ul>
#             <div class="infected">
#                 <h4>Harmful items:</h4>
#                 <ul class="list_infected">
#                     <li>
#                         <a href="https://ws.fsapi.com/cgi-bin/AT-Vdescssearch.cgi?search=EICAR_Test_File">EICAR_Test_File</a>
#                         <ul>
#                             <li>C:\Users\Administrator\Desktop\eicar\eicar1.com</li>
#                         </ul>
#                     </li>
#                     <li>
#                         <a href="https://ws.fsapi.com/cgi-bin/AT-Vdescssearch.cgi?search=EICAR_Test_File">EICAR_Test_File</a>
#                         <ul>
#                             <li>C:\Users\Administrator\Desktop\eicar\eicar2.com</li>
#                         </ul>
#                     </li>
#                     <li>
#                         <a href="https://ws.fsapi.com/cgi-bin/AT-Vdescssearch.cgi?search=EICAR_Test_File">EICAR_Test_File</a>
#                         <ul>
#                             <li>C:\Users\Administrator\Desktop\eicar\eicar3.com</li>
#                         </ul>
#                     </li>
#                     <li>
#                         <a href="https://ws.fsapi.com/cgi-bin/AT-Vdescssearch.cgi?search=EICAR_Test_File">EICAR_Test_File</a>
#                         <ul>
#                             <li>C:\Users\Administrator\Desktop\eicar\eicar4.com</li>
#                         </ul>
#                     </li>
#                 </ul>
#             </div>
#         </div>
#         <div class="section_info">
#             <h2>Version information</h2>
#             <h4>Scanning engines:</h4>
#             <ul class="list_engines">
#                 <li>F-Secure Capricorn: 18.0.936 (2023-05-30)</li>
#                 <li>F-Secure Hydra: 6.0.573 (2023-05-30)</li>
#                 <li>F-Secure Lynx: 2.6.4</li>
#                 <li>F-Secure Online: 18.10.1425</li>
#                 <li>F-Secure USS: 6.0.208 (2020-04-14)</li>
#                 <li>F-Secure Virgo: 1.3.48 (2023-05-22)</li>
#                 <li>F-Secure Virgo Detection: 18.10.1425</li>
#             </ul>
#         </div>
#         <div class="section_legal">
#             <p>Copyright © 1998 - 2021 F-Secure Corporation. All rights reserved.</p>
#             <p>
#                 <a href="">Product support</a> |                 <a href="https://www.f-secure.com/sas">Send a sample to F-Secure</a>
#             </p>
#             <p>F-Secure assumes no responsibility for material created or published by third parties that F-Secure World Wide Web pages have a link to. Unless you have clearly stated otherwise, by submitting material to any of our servers, for example by E-mail or via our F-Secure's CGI E-mail, you agree that the material you make available may be published in the F-Secure World Wide Pages or hard-copy publications. You will reach F-Secure public web site by clicking on underlined links. While doing this, your access will be logged to our private access statistics with your domain name. This information will not be given to any third party. You agree not to take action against us in relation to material that you submit. Unless you have clearly stated otherwise, by submitting material you warrant that F-Secure may incorporate any concepts described in it in the F-Secure products/publications without liability.</p>
#         </div>
#     </body>
# </html>
# "@
# scanReportProcesss $HtmlContent