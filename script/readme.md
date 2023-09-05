# dir define
```dir
+---c
    +---script              // 各種語言寫成的腳本 
        +---ps1
            +---config              // credential.json,config.json
            +---function            // 共用功能
            +---xxxjob              // 腳本位置(若為單一工作多個腳本應放同一個資料夾)
        +---bat
            ...
        +---sh
            ...
        +---py
            ...
        +---log                 // 存放結果
            +---xxxjob_log          //與job名稱相同方便尋找
```

# todo
* 更細化流程
* 多線程版本僅在掃毒時多線程，其他不用。
* 放在git公開儲存庫(注意好資安 公司、產品、帳密、mail)
# wade
* 加入linux掃毒
* open source軟體怎麼說服老闆?
# change log
* 20230901 git控制
* 20230903 修正硬碟判斷，不要讀取ISCSI、SMB的硬碟
* 20230905 修正避開已安裝防毒的機器
* 20230905 抽離config檔案