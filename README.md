4d-plugin-document-properties
=============================

Commands to get/set folder/file dates, get/set the hidden attribute.

###Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|🆗|🆗|🆗|🆗|

###Version

<img src="https://cloud.githubusercontent.com/assets/1725068/18940649/21945000-8645-11e6-86ed-4a0f800e5a73.png" width="32" height="32" /> <img src="https://cloud.githubusercontent.com/assets/1725068/18940648/2192ddba-8645-11e6-864d-6d5692d55717.png" width="32" height="32" />

* Related Commands

[SET DOCUMENT PROPERTIES](http://doc.4d.com/4Dv16/4D/16/SET-DOCUMENT-PROPERTIES.301-3036736.en.html)

[GET DOCUMENT PROPERTIES](http://doc.4d.com/4Dv16/4D/16/GET-DOCUMENT-PROPERTIES.301-3036712.en.html)

Commands
---

```
PATH Get creation date
PATH Set modification date
PATH Get modification date
PATH Set creation date
PATH Get access date
PATH Set access date
PATH Get hidden
PATH Set hidden
```

Examples
---

```
C_BLOB($void)

$filePath:=System folder(Desktop)+Generate UUID

BLOB TO DOCUMENT($filePath;$void)

$error:=PATH Get access date ($filePath;$accessDate;$accessTime)
$error:=PATH Get creation date ($filePath;$creationDate;$creationTime)
$error:=PATH Get modification date ($filePath;$modificationDate;$modificationTime)

$error:=PATH Set access date ($filePath;!2001-01-01!;?01:01:01?)
$error:=PATH Set creation date ($filePath;!2001-01-01!;?01:01:01?)
$error:=PATH Set modification date ($filePath;!2001-01-01!;?01:01:01?)

$error:=PATH Get access date ($filePath;$accessDate;$accessTime)
$error:=PATH Get creation date ($filePath;$creationDate;$creationTime)
$error:=PATH Get modification date ($filePath;$modificationDate;$modificationTime)

DELETE DOCUMENT($filePath)

  //works for folders too

$error:=PATH Get access date (Get 4D folder(Current resources folder);$accessDate;$accessTime)
$error:=PATH Get creation date (Get 4D folder(Current resources folder);$creationDate;$creationTime)
$error:=PATH Get modification date (Get 4D folder(Current resources folder);$modificationDate;$modificationTime)
```

```
C_BLOB($void)

$filePath:=System folder(Desktop)+Generate UUID

BLOB TO DOCUMENT($filePath;$void)
$error:=PATH Get hidden ($filePath;$hidden)
$error:=PATH Set hidden ($filePath;1)
$error:=PATH Get hidden ($filePath;$hidden)
$error:=PATH Set hidden ($filePath;0)
$error:=PATH Get hidden ($filePath;$hidden)
DELETE DOCUMENT($filePath)

$folderPath:=System folder(Desktop)+Generate UUID

CREATE FOLDER($folderPath)
$error:=PATH Get hidden ($folderPath;$hidden)
$error:=PATH Set hidden ($folderPath;1)
$error:=PATH Get hidden ($folderPath;$hidden)
$error:=PATH Set hidden ($folderPath;0)
$error:=PATH Get hidden ($folderPath;$hidden)
DELETE FOLDER($folderPath)
```
