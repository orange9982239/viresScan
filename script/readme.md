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
* 修正硬碟判斷，不要讀取虛擬的、外掛、ISCSI、過大的硬碟
* 修正避開已安裝防毒的機器
* 加入多現成版本

# change log
* 20230901 git控制