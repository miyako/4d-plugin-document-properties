# 4d-plugin-document-properties

Document Properties is a 4D plugin that reads and sets the creation, modification and last-access dates of files and folders, and reads and sets their hidden attribute. It works on folders as well as files. **On macOS** it calls `stat`, `setattrlist` and `chflags`. **On Windows** it calls `GetFileTime`/`SetFileTime` and `GetFileAttributesW`/`SetFileAttributesW`. Dates and times are exchanged as 4D `Date` and `Time` values in local time. Every command returns a `Longint` error code, which is `0` on success.

| Command | Returns | Purpose |
|:--|:--|:--|
| [`PATH Get creation date`](#path-get-creation-date) | `Longint` | Read the creation date and time |
| [`PATH Set creation date`](#path-set-creation-date) | `Longint` | Change the creation date and time |
| [`PATH Get modification date`](#path-get-modification-date) | `Longint` | Read the last-modification date and time |
| [`PATH Set modification date`](#path-set-modification-date) | `Longint` | Change the last-modification date and time |
| [`PATH Get access date`](#path-get-access-date) | `Longint` | Read the last-access date and time |
| [`PATH Set access date`](#path-set-access-date) | `Longint` | Change the last-access date and time |
| [`PATH Get hidden`](#path-get-hidden) | `Longint` | Read the hidden attribute |
| [`PATH Set hidden`](#path-set-hidden) | `Longint` | Set or clear the hidden attribute |

**Platforms:** macOS 10.13+ (Universal: Apple silicon and Intel), Windows 64-bit

## Versioning and manual publication

Run **Bump version** manually with `patch`, `minor` or `major` on the branch
selected in Actions. It validates the immutable dispatch SHA and clean source,
commits only source metadata, and nonforce-pushes only that explicit branch.
It creates no tag and starts no Build. A mandatory executable pre-push guard
checks the advertised old SHA against the selected SHA, and the new commit,
parent and destination against the prepared update. Even a late branch advance,
rewind, deletion or same-result update is rejected. Missing/nonexecutable guards
fail closed. Both `push.followTags=false` and `--no-follow-tags` prevent unrelated
annotated tags from following the push. If the branch moved, dispatch again on
its new commit after review.

Source authority is the strict `X.Y.Z` `MARKETING_VERSION` inherited from the
three Xcode project configurations. The historical Bump header explicitly
promised coordinated marketing/current versions; commit `8bd55a8` updated both,
but `2b71438` updated only marketing and the source plist. This migration repairs
the three stale `CURRENT_PROJECT_VERSION` settings and the localized source
short/info strings to **the existing 2.1.0**, without a release increment.
Future bumps validate and coordinate those settings, `Info.plist` version keys
and `English.lproj/InfoPlist.strings`. Legitimate `$(...)`/`${...}` version
references are retained; absent `CFBundleVersion` remains absent. Prebuilt
bundles, 4D project data, `manifest.json` schema version, dependency metadata and
localization counters are not version inputs and are not rewritten.

Run **Build** separately on the desired source revision. It has only
`workflow_dispatch`, zero typed inputs, and every checkout uses `github.sha`.
There is no tag-push build or new default-branch-only restriction. Publication
is serialized repo-wide across branches without cancelling a running build.
Before native work, and again immediately after all required native/package/
codesign/notary/staple gates, authenticated checks inspect remote tags and every
page of releases, including drafts. Existing names, malformed responses,
authentication/network errors and later-page failures stop publication.
Only a complete successful no-match permits create-only publication: a new
lightweight `vX.Y.Z` tag at the exact selected SHA, verified remotely, then a new
non-draft/non-prerelease release with empty notes (the original notes policy).
Assets are uploaded separately to that returned new release ID, with no
overwrite: `Document Properties-X.Y.Z.zip` and `Document Properties-X.Y.Z.dmg`.
Concurrent same-SHA and different-SHA tag creations both fail.

**Recovery:** failures do not delete, update, roll back or retry remote state.
A tag, release or previously uploaded asset may remain even if a response was
lost or malformed. Inspect the run and retained remote state before taking any
separate maintainer recovery action; rerunning the same version will refuse
existing state. Do not assume a failed run left nothing published.

The existing Windows x64 MSBuild/v143 and macOS universal build, bundled 4D API,
resource/Rez phases, signing credentials and signing/notary/staple gates remain
unchanged. This workflow migration does not modernize legacy native phases or
prove hosted-runner SDK/tool compatibility. ZIP notarization and DMG
notarization/stapling retain their original behavior; the ZIP is not stapled.
No native/signing execution is part of the migration checks.

Lifecycle checks (no native tools or signing needed):
`python3 -m unittest discover -s .github/tests -v` and
`actionlint .github/workflows/*.yml`. The suite uses live source-derived fixtures,
mocked authenticated API pages and temporary real bare Git repositories for races.

---

## Requirements & platform notes

- **Pass a native platform path.** `path` must be in the system's own format: a colon-separated path **on macOS** (what `System folder`, `Get 4D folder` and `Document` return), or a backslash path **on Windows**. **On macOS, a POSIX path such as `/Users/me/file.txt` is not accepted.** The plugin interprets it as a colon-separated path, so it names a different item, and the command usually fails with error `2`. If you have a `File` or `Folder` object, pass its `.platformPath`.
- **Errors are return codes, not 4D errors.** No command raises a 4D error or shows a dialog. Always check the returned `Longint`. **On macOS** it is a POSIX `errno` value. **On Windows** it is a Win32 system error code (`GetLastError`). The two platforms use different numbers for the same problem (see [Error handling & troubleshooting](#error-handling--troubleshooting)).
- **All parameters are mandatory.** No command has an optional form.
- **Dates are local time, to the second.** Values are converted between UTC and the computer's current time zone, using the daylight-saving rule in effect *on that date*. Fractions of a second are dropped when reading. When setting, the fraction is set to `0`.
- **Symbolic links and aliases.** All the date commands act on the item a symbolic link points to, on both platforms. [`PATH Get hidden`](#path-get-hidden)/[`PATH Set hidden`](#path-set-hidden) act on the target **on macOS**, but on the link itself **on Windows**. Finder aliases are ordinary files to these commands, so they act on the alias file, not on its original.
- **Thread-safe.** Every command is declared thread-safe, so you can call it from preemptive processes.

> **Applies to builds from this source revision onward.** Earlier binaries, up to and including release 2.0, differ:
> - On Windows, the 2.0 binary returned the access date from [`PATH Get modification date`](#path-get-modification-date) and the modification date from [`PATH Get access date`](#path-get-access-date).
> - On Windows, the 2.0 binary returned `0` with an empty date for a path it could not open.
> - On Windows, the 2.0 binary could not set dates on read-only files or on files another application had open.
> - On macOS, the 2.0 binary returned Cocoa error codes (for example `260` for a missing file) instead of `errno` values from the creation and modification date commands.
> - Neither platform rejected invalid dates or times.

---

## PATH Get creation date

### Syntax

```
error := PATH Get creation date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | Receives the creation date (local time) |
| `time` | Time | Receives the creation time (local time) |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Reads the date and time the item at `path` was created and returns them in `date` and `time`.

If the command fails, `date` is set to `!00-00-00!` and `time` to `?00:00:00?`. Check the result before using them.

**On macOS** the value is the file system's birth time. **On Windows** it is the NTFS creation time. Copying a file usually gives the copy a new creation date.

### Example

From the original README:

```4d
C_BLOB($void)

$filePath:=System folder(Desktop)+Generate UUID

BLOB TO DOCUMENT($filePath;$void)

$error:=PATH Get creation date ($filePath;$creationDate;$creationTime)
```

Read the creation date of a folder (the original README notes that folders work too):

```4d
$error:=PATH Get creation date (Get 4D folder(Current resources folder);$creationDate;$creationTime)
```

Check the result before using the values:

```4d
C_DATE($d)
C_TIME($t)
C_LONGINT($error)

$error:=PATH Get creation date ($path;$d;$t)
If ($error=0)
	ALERT("Created on "+String($d)+" at "+String($t))
Else
	ALERT("Could not read the creation date (error "+String($error)+")")
End if
```

---

## PATH Set creation date

### Syntax

```
error := PATH Set creation date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | New creation date (local time) |
| `time` | Time | New creation time (local time), from `?00:00:00?` to `?23:59:59?` |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Sets the creation date and time of the item at `path`. The modification and access dates are not changed.

`date` and `time` are checked before anything is written. The command returns `22` **on macOS** or `87` **on Windows** without touching the item when:
- `date` is the null date `!00-00-00!`
- `date` is not a real calendar date
- `time` is negative or at least `?24:00:00?`

**On Windows** the earliest date a file can carry is 1601-01-01.

You need permission to change the item's attributes:
- **On macOS** you must own the item, otherwise the command returns `1` (`EPERM`).
- **On Windows** you need the write-attributes right. Read-only files and files another application has open can still be changed.

### Example

From the original README:

```4d
$error:=PATH Set creation date ($filePath;!2001-01-01!;?01:01:01?)
```

Give a file the current date and time as its creation date:

```4d
$error:=PATH Set creation date ($path;Current date;Current time)
```

---

## PATH Get modification date

### Syntax

```
error := PATH Get modification date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | Receives the last-modification date (local time) |
| `time` | Time | Receives the last-modification time (local time) |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Reads the date and time the content of the item at `path` was last changed. For a folder, that is the last time an item was added to it, removed from it or renamed in it.

If the command fails, `date` is set to `!00-00-00!` and `time` to `?00:00:00?`.

### Example

From the original README:

```4d
$error:=PATH Get modification date ($filePath;$modificationDate;$modificationTime)
```

List the documents in a folder that were modified today:

```4d
ARRAY TEXT($names;0)
C_TEXT($folder)
C_DATE($d)
C_TIME($t)
C_LONGINT($i;$error)

$folder:=System folder(Desktop)
DOCUMENT LIST($folder;$names)

For ($i;1;Size of array($names))
	$error:=PATH Get modification date ($folder+$names{$i};$d;$t)
	If (($error=0) & ($d=Current date))
		// $names{$i} was modified today
	End if
End for
```

---

## PATH Set modification date

### Syntax

```
error := PATH Set modification date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | New modification date (local time) |
| `time` | Time | New modification time (local time), from `?00:00:00?` to `?23:59:59?` |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Sets the last-modification date and time of the item at `path`. The creation and access dates are not changed. The date/time checks and permission rules are the same as for [`PATH Set creation date`](#path-set-creation-date).

Changing the modification date can affect backup, sync and build tools that use it to detect changed files.

### Example

From the original README:

```4d
$error:=PATH Set modification date ($filePath;!2001-01-01!;?01:01:01?)
```

Copy the modification date from one file to another:

```4d
C_DATE($d)
C_TIME($t)
C_LONGINT($error)

$error:=PATH Get modification date ($source;$d;$t)
If ($error=0)
	$error:=PATH Set modification date ($target;$d;$t)
End if
```

---

## PATH Get access date

### Syntax

```
error := PATH Get access date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | Receives the last-access date (local time) |
| `time` | Time | Receives the last-access time (local time) |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Reads the date and time the item at `path` was last accessed.

The operating system decides when this value is updated, and it is often not updated on every read. Windows can turn last-access updates off entirely, and macOS updates it only in some cases. Treat the value as approximate. Don't use it to tell whether a file has been read since a given time.

If the command fails, `date` is set to `!00-00-00!` and `time` to `?00:00:00?`.

### Example

From the original README:

```4d
$error:=PATH Get access date ($filePath;$accessDate;$accessTime)
```

---

## PATH Set access date

### Syntax

```
error := PATH Set access date ( path ; date ; time )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `date` | Date | New access date (local time) |
| `time` | Time | New access time (local time), from `?00:00:00?` to `?23:59:59?` |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Sets the last-access date and time of the item at `path`. The creation and modification dates are not changed, including the fractional seconds of the modification date. The date/time checks and permission rules are the same as for [`PATH Set creation date`](#path-set-creation-date).

### Example

From the original README:

```4d
$error:=PATH Set access date ($filePath;!2001-01-01!;?01:01:01?)
```

Set all three dates of a file to the same moment:

```4d
C_DATE($d)
C_TIME($t)
C_LONGINT($error)

$d:=!2020-01-15!
$t:=?08:30:00?

$error:=PATH Set creation date ($path;$d;$t)
If ($error=0)
	$error:=PATH Set modification date ($path;$d;$t)
End if
If ($error=0)
	$error:=PATH Set access date ($path;$d;$t)
End if
```

---

## PATH Get hidden

### Syntax

```
error := PATH Get hidden ( path ; hidden )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `hidden` | Longint | Receives `1` if the item is hidden, `0` if not |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Reports whether the item at `path` has the hidden attribute.
- **On macOS** this is the `UF_HIDDEN` file flag, the one `chflags hidden` sets. Names starting with a dot (`.gitignore`) are hidden by Finder whether or not they have the flag, and this command returns `0` for them unless the flag is also set.
- **On Windows** this is `FILE_ATTRIBUTE_HIDDEN`.

If the command fails, `hidden` is set to `0`.

### Example

From the original README:

```4d
$error:=PATH Get hidden ($filePath;$hidden)
```

---

## PATH Set hidden

### Syntax

```
error := PATH Set hidden ( path ; hidden )
```

| Parameter | Type | Description |
|:--|:--|:--|
| `path` | Text | Native path of a file or folder |
| `hidden` | Longint | Any non-zero value hides the item; `0` makes it visible |
| Result | Longint | `0` on success, otherwise an error code |

### Description

Sets or clears the hidden attribute of the item at `path`. All other file flags and attributes are left as they are.
- **On macOS** the command sets or clears `UF_HIDDEN`. It cannot make a dot-file visible, because Finder hides those by name.
- **On Windows** it sets or clears `FILE_ATTRIBUTE_HIDDEN`. Explorer still shows hidden items when "Show hidden files" is on.

### Example

From the original README:

```4d
C_BLOB($void)

$filePath:=System folder(Desktop)+Generate UUID

BLOB TO DOCUMENT($filePath;$void)
$error:=PATH Get hidden ($filePath;$hidden)
$error:=PATH Set hidden ($filePath;1)
$error:=PATH Get hidden ($filePath;$hidden)
$error:=PATH Set hidden ($filePath;0)
$error:=PATH Get hidden ($filePath;$hidden)
DELETE DOCUMENT($filePath)
```

The same for a folder, also from the original README:

```4d
$folderPath:=System folder(Desktop)+Generate UUID

CREATE FOLDER($folderPath)
$error:=PATH Set hidden ($folderPath;1)
$error:=PATH Get hidden ($folderPath;$hidden)
DELETE FOLDER($folderPath)
```

Toggle the hidden attribute:

```4d
C_LONGINT($hidden;$error)

$error:=PATH Get hidden ($path;$hidden)
If ($error=0)
	If ($hidden=1)
		$error:=PATH Set hidden ($path;0)
	Else
		$error:=PATH Set hidden ($path;1)
	End if
End if
```

---

## Error handling & troubleshooting

- **Check every result.** A failed Get command still fills in its output parameters (`!00-00-00!`, `?00:00:00?` or `0`), so an unchecked failure looks like a real but wrong value.
- **Error codes depend on the platform.** Common values:

  | Problem | macOS | Windows |
  |:--|:--|:--|
  | Item not found | `2` | `2` (file) or `3` (path) |
  | Permission denied | `1` or `13` | `5` |
  | Invalid date or time passed to a Set command | `22` | `87` |
  | Path too long | `63` | `206` or `3`, depending on the path |
  | Out of memory | `12` | `8` |

- **Error 2 on macOS for a path that exists.** You probably passed a POSIX path (`/Users/...`). Pass the colon-separated path, or `.platformPath` of a `File`/`Folder` object.
- **A Set command returns 22 or 87.** The date is null or not a real date, or the time is outside `?00:00:00?`–`?23:59:59?`. Nothing was changed.
- **A Set command returns 1 (macOS) or 5 (Windows).** You don't have permission to change the item's attributes. On macOS you must own the item. Some volumes (for example some network or FAT/exFAT shares) can't store every date. Creation dates in particular may not be supported.
- **The time is one hour off.** Values are local time, using the daylight-saving rule for that date. A file stored on a volume with no time zone information (such as FAT) can still be off by one hour.
- **The access date doesn't change after reading a file.** The operating system controls when it's updated. See [`PATH Get access date`](#path-get-access-date).
- **A dot-file reports `hidden = 0` on macOS.** Finder hides it by name; this command reads only the `UF_HIDDEN` flag. See [`PATH Get hidden`](#path-get-hidden).
- **Hidden attribute and symbolic links on Windows.** [`PATH Set hidden`](#path-set-hidden) changes the link itself on Windows, but the link's target on macOS.
- **Slow or unresponsive network paths.** Each call waits for the file system. An unreachable network volume can block the calling process until the system times out. To keep the user interface responsive, run such calls in a worker or a separate process.

---

## Quick reference

```4d
C_DATE($d)
C_TIME($t)
C_LONGINT($error;$hidden)

$error:=PATH Get creation date ($path;$d;$t)
$error:=PATH Get modification date ($path;$d;$t)
$error:=PATH Get access date ($path;$d;$t)

$error:=PATH Set creation date ($path;!2001-01-01!;?01:01:01?)
$error:=PATH Set modification date ($path;Current date;Current time)
$error:=PATH Set access date ($path;$d;$t)

$error:=PATH Get hidden ($path;$hidden)
$error:=PATH Set hidden ($path;1)  // 0 to show
```
