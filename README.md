4d-plugin-document-properties
=============================

Commands to get/set folder/file dates, get/set the hidden attribute.

##Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|🆗|🚫|🆗|🆗|

Commands
---

```c
// --- Files and Folders
void PATH_Get_creation_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Set_modification_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Get_modification_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Set_creation_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Get_access_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Set_access_date(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Get_hidden(sLONG_PTR *pResult, PackagePtr pParams);
void PATH_Set_hidden(sLONG_PTR *pResult, PackagePtr pParams);
```
