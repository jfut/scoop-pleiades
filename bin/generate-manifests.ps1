$templateStringNoarch = @"
{
    "homepage": "http://mergedoc.osdn.jp/",
    "license": "https://www.eclipse.org/legal/epl-v10.html",
    "version": "%version%",
    "url": "%url%#/dl.7z",
    "hash": "%hash%",
    "extract_dir": "pleiades",
    "persist": [
        "eclipse\\configuration",
        "workspace"
    ],
    "shortcuts": [
        [
            "eclipse/eclipse.exe",
            "Pleiades All in One %langLabel% %version%"
        ]
    ],
    "post_install": "
        `$shortcuts = @(arch_specific 'shortcuts' `$manifest `$arch)
        `$shortcutName = `$shortcuts[0].item(1)
        `$scoop_startmenu_folder = shortcut_folder `$global
        `$wsShell = New-Object -ComObject WScript.Shell
        `$shortcut = `$wsShell.CreateShortcut(\"`$scoop_startmenu_folder\\`$shortcutName.lnk\")
        `$shortcut.WorkingDirectory = \"`$dir\\eclipse\"
        `$shortcut.Save()
    ",
    "checkver": {
        "url": "http://mergedoc.osdn.jp/pleiades_distros%majorVersion%.html",
        "re": "%checkver_re%"
    },
    "autoupdate": {
        "url": "http://ftp.jaist.ac.jp/pub/mergedoc/pleiades/`$majorVersion.`$minorVersion/pleiades-`$fileVersion-java-win-64bit-jre_`$date.zip#/dl.7z"
    }
}
"@

$templateString = @"
{
    "homepage": "http://mergedoc.osdn.jp/",
    "license": "https://www.eclipse.org/legal/epl-v10.html",
    "version": "%version%",
    "architecture": {
%architecture%
    },
    "extract_dir": "pleiades",
    "persist": [
        "eclipse\\configuration",
        "workspace"
    ],
    "shortcuts": [
        [
            "eclipse/eclipse.exe",
            "Pleiades All in One %langLabel% %version%"
        ]
    ],
    "post_install": "
        `$shortcuts = @(arch_specific 'shortcuts' `$manifest `$arch)
        `$shortcutName = `$shortcuts[0].item(1)
        `$scoop_startmenu_folder = shortcut_folder `$global
        `$wsShell = New-Object -ComObject WScript.Shell
        `$shortcut = `$wsShell.CreateShortcut(\"`$scoop_startmenu_folder\\`$shortcutName.lnk\")
        `$shortcut.WorkingDirectory = \"`$dir\\eclipse\"
        `$shortcut.Save()
    ",
    "checkver": {
        "url": "http://mergedoc.osdn.jp/pleiades_distros%majorVersion%.html",
        "re": "%checkver_re%"
    },
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "http://ftp.jaist.ac.jp/pub/mergedoc/pleiades/`$majorVersion.`$minorVersion/pleiades-`$fileVersion-java-win-64bit-jre_`$date.zip#/dl.7z"
            },
            "32bit": {
                "url": "http://ftp.jaist.ac.jp/pub/mergedoc/pleiades/`$majorVersion.`$minorVersion/pleiades-`$fileVersion-java-win-32bit-jre_`$date.zip#/dl.7z"
            }
        }
    }
}
"@

$templateString64bit = @"
        "64bit": {
            "url": "%64bit-url%#/dl.7z",
            "hash": "%64bit-hash%"
        }
"@
$templateString32bit = @"
        "32bit": {
            "url": "%32bit-url%#/dl.7z",
            "hash": "%32bit-hash%"
        }
"@

$baseUrl = "http://mergedoc.osdn.jp/pleiades-redirect/"
$baseVersionUrl = "http://mergedoc.osdn.jp/pleiades_distros"
$baseDownloadUrl = "http://ftp.jaist.ac.jp/pub/mergedoc/pleiades/"

$langLabelHash = @{
    cpp = "CDT";
    java = "Java";
    php = "PHP";
    platform = "Platform";
    python = "Python";
    ultimate = "Ultimate";
}

$checkverRegex = @{
    base_version = "Pleiades All in One ((?<fileVersion>[\\d.]+).*\\.v(?<date>[\\d]+))";
    base_version_win = "Pleiades All in One ((?<fileVersion>[\\w\\d\\.]+) \\(Windows (?<date>[\\w\\d\\.]+).+\\))";
    base_version_mac = "Pleiades All in One ((?<fileVersion>[\\w\\d\\.]+) \\(.+, Mac (?<date>[\\w\\d\\.]+)\\))";
    date_version = "((?<fileVersion>[\\d]{4}-[\\d]{2})\\.(?<date>[\\d]{8}))";
}

# [4.6 or later]
# - pleiades_cpp-win-32bit.zip.html
# - pleiades_cpp-win-32bit_jre.zip.html
function match_lang_os_arch_edition($matches, $lang, $os, $arch, $edition) {
    if ($matches['lang']) {
        $lang = $matches['lang']
    }
    if ($matches['os']) {
        $os = $matches['os']
    }
    if ($matches['arch']) {
        $arch = $matches['arch']
    }
    if ($matches['jre']) {
        $edition = "full"
    }
    return $lang, $os, $arch, $edition
}

# Fetch majorVersions
$wc = new-object net.webclient
$html = $wc.downloadstring("$baseUrl")

# TODO: 3.x support
# 4.3 - 4.8, 20YY
$versionMatch = ([regex]">(4[\d.]+|20\d\d)/").matches($html)
$majorVersions = @()
$versionMatch |% {
    $majorVersions += $_.groups[1].value
}
# debug
#$majorVersions = $("4.2")
#$majorVersions = $("4.3", "4.4")
#$majorVersions = $("4.5", "4.6", "4.7")
#$majorVersions = $("4.7","4.8")
# new date version format
#$majorVersions = $("2018")
# 64-bit only
#$majorVersions = $("2019")

# Generate manifestHash
$manifestHash = @{}
$majorVersions | ForEach-Object {
    $majorVersion = $_
    $versionHtml = $wc.downloadstring("$baseUrl/$majorVersion/")
    $linkMatch = ([regex]">(pleiades_.+zip.html)<").matches($versionHtml)
    $linkMatch |% {
        $link = $_.groups[1].value

        # debug
        #if ($link -match "^(?!.*java)") {
        #    return
        #}

        write-host "# $link" -ForegroundColor Yellow

        # Fetch parameters
        $os = "win"
        $arch = "noarch"
        # [- 4.5] + not 2018
        if ($majorVersion.Length -eq 3 -and $majorVersion -le "4.5") {
            $arch = "64bit"
        }
        $edition = "standard"
        # [4.6 or later]
        # - pleiades_cpp-win-32bit.zip.html
        # - pleiades_cpp-win-32bit_jre.zip.html
        if ($link -match "pleiades_(?<lang>.+)-(?<os>.+)-(?<arch>32bit|64bit)(|(?<jre>_jre))\.zip\.html") {
            $lang, $os, $arch, $edition = match_lang_os_arch_edition $matches $lang $os $arch $edition
            write-host " - 1. $lang, $os, $arch, $jre, $edition"
        }
        # [4.5]
        # - pleiades_cpp-32bit.zip.html
        # - pleiades_cpp-32bit_jre.zip.html
        elseif ($link -match "pleiades_(?<lang>.+)-(?<arch>32bit|64bit)(?<jre>_jre)?.zip.html") {
            # 4.6 + no os is obsolute.
            if ($majorVersion -eq "4.6") {
                write-host "Skip: $link (obsolute)"
                return
            }
            $lang, $os, $arch, $edition = match_lang_os_arch_edition $matches $lang $os $arch $edition
            write-host " - 2. $lang, $os, $arch, $jre, $edition"
        }
        # pleiades_cpp-mac.zip.html
        # pleiades_cpp-mac_jre.zip.html
        elseif ($link -match "pleiades_(?<lang>.+)-(?<os>.+?)(?<jre>_jre)?.zip.html") {
            $lang, $os, $arch, $edition = match_lang_os_arch_edition $matches $lang $os $arch $edition
            write-host " - 3. $lang, $os, $arch, $jre, $edition"
        }
        # pleiades_cpp.zip.html
        # pleiades_cpp_jre.zip.html
        elseif ($link -match "pleiades_(?<lang>.+?)(|(?<jre>_jre)).zip.html") {
            # 4.6 + no os is obsolute.
            if ($majorVersion -eq "4.6") {
                write-host "Skip: $link (obsolute)"
                return
            }
            $lang, $os, $arch, $edition = match_lang_os_arch_edition $matches $lang $os $arch $edition
            write-host " - 4. $lang, $os, $arch, $jre, $edition"
        } else {
            write-host "Skip: $link (unkown version)" -ForegroundColor Red
            return
        }

        # Fetch version
        $version = ""
        $versionHtml = $wc.downloadstring("$baseVersionUrl$majorVersion.html")
        # format: Pleiades All in One 4.8.0 (Windows 20180923, Mac 20180627)
        if ($os -match "win") {
            if ($versionHtml -match "Pleiades All in One (?<fileVersion>\d[\w\.]+) \(Windows (?<date>\d+)") {
                $version = $matches['fileVersion'] + ".v" + $matches['date']
            }
        } else {
            if ($versionHtml -match "Pleiades All in One (?<fileVersion>\d[\w\.]+).* Mac (?<date>\d+)") {
                $version = $matches['fileVersion'] + ".v" + $matches['date']
            }
        }
        # format: Pleiades All in One 4.6.3.v20170422
        if ($version -match "") {
            if ($versionHtml -match "Pleiades All in One (?<version>[\d.]+.*\.v[\d]+)") {
                $version = $matches['version']
            }
        }
        # [2018 or later]
        # format: 2018-09.20181004
        if ($majorVersion.Length -eq 4 -and $majorVersion -ge "2018") {
            if ($versionHtml -match "(?<fileVersion>[\d]{4}-[\d]{2})\.(?<date>[\d]{8})") {
                $version = $matches['fileVersion'] + "." + $matches['date']
                # write-host " - $majorVersion version, $version, $date"
            }
        }
        #write-host " - version, $version"

        # Fetch file name and hash
        $downloadUrl = "$baseUrl$majorVersion/$link"
        #write-host " - downloadUrl, $downloadUrl"
        # Special case
        if ($majorVersion -eq "4.5" -and $link -eq "pleiades_java-32bit_jre.zip.html") {
            $downloadUrl = "$baseUrl$majorVersion/pleiades_java-32bit_jre.zip_MD5.html"
        }
        $downloadHtml = $wc.downloadstring("$downloadUrl")
        if ($downloadHtml -match "(?<downloadFile>[\d.]+/pleiades-[\d\w.]+[\w-.]+)") {
            $downloadFile = $matches['downloadFile']
        }
        $hash = $null
        if ($downloadHtml -match "MD5: (?<hash>[\w]+)") {
            $hash = "md5:" + $matches['hash']
        }

        # Detect checkver
        # [4.2 - 4.6]
        $checkver_re = $checkverRegex['base_version']
        # [4.7 - 4.8]
        if ($majorVersion.Length -eq 3 -and ($majorVersion -eq "4.7" -or $majorVersion -eq "4.8")) {
            if ($os -eq "win") {
                $checkver_re = $checkverRegex['base_version_win']
            } else {
                $checkver_re = $checkverRegex['base_version_mac']
            }
            # replace: 4.7.3a (Windows 20180411, Mac 20180618) -> 4.7.3a.v20180411
            $checkver_re += "`",`r`n" + @"
        "replace": "`${fileVersion}.v`${date}
"@
        }
        # [2018 or later]
        elseif ($majorVersion.Length -eq 4 -and $majorVersion -ge "2018") {
            $checkver_re = $checkverRegex['date_version']
        }

        # Create manifest hash
        $key = "pleiades$majorVersion-$lang-$os-$edition"
        write-host " - [key] $key, $downloadFile, $hash"
        $archHash = @{}
        if ($manifestHash.contains($key)) {
            write-host " - [update] $key, $lang, $os, $arch, $edition"
            $archHash = $manifestHash[$key]
            if (! $archHash.contains($arch)) {
                $archHash.add($arch, @{
                    url = "$baseDownloadUrl$downloadFile";
                    hash = $hash
                })
            }
        } else {
            write-host " - [new] $key, $lang, $os, $arch, $edition"
            $archHash.add("common", @{
                version = $version;
                majorVersion = $majorVersion;
                lang = $lang;
                os = $os;
                edition = $edition;
                checkver_re = $checkver_re;
            })
            $archHash.add($arch, @{
                url = "$baseDownloadUrl$downloadFile";
                hash = $hash
            })
            $manifestHash.add($key, $archHash)
        }
        write-host ""

        # Mitigate 403 error
        Start-Sleep -Milliseconds 50
    }
}

#
# Generate manifest files from $manifestHash
#

# pleiades-java-win-full.json
# pleiades47-java-win-full.json
# pleiades2018-java-win-full.json
write-host "# outpue manifest file"
$manifestHash.Keys | ForEach-Object {
    $key = $_
    $archHash = $manifestHash[$key]
    if ($archHash.contains('noarch')) {
        write-host "$key [noarch]"
        $manifest = $templateStringNoarch
        $manifest = $manifest -replace "%url%", $archHash['noarch']['url']
        $hash = $archHash['noarch']['hash']
        if ($hash -eq $null) {
            $manifest = $manifest -replace ",\r\n.*%hash%.*\r\n", "`r`n"
        } else {
            $manifest = $manifest -replace "%hash%", $archHash['noarch']['hash']
        }
    } else {
        write-host "$key [64bit, 32bit]"
        $manifest = $templateString

        # 64bit
        $arch64bit = $templateString64bit
        $arch64bit = $arch64bit -replace "%64bit-url%", $archHash['64bit']['url']
        $hash = $archHash['64bit']['hash']
        if ($hash -eq $null) {
            $arch64bit = $arch64bit -replace ",\r\n.*%64bit-hash%.*\r\n", "`r`n"
        } else {
            $arch64bit = $arch64bit -replace "%64bit-hash%", $archHash['64bit']['hash']
        }

        if ($archHash['32bit'] -eq $null) {
            # 64bit only
            $manifest = $manifest -replace "%architecture%", $arch64bit
        } else {
            # 64bit + 32bit
            $arch32bit = $templateString32bit
            $arch32bit = $arch32bit -replace "%32bit-url%", $archHash['32bit']['url']
            $hash = $archHash['32bit']['hash']
            if ($hash -eq $null) {
                $arch32bit = $arch32bit -replace ",\r\n.*%32bit-hash%.*\r\n", "`r`n"
            } else {
                $arch32bit = $arch32bit -replace "%32bit-hash%", $hash
            }

            $architecture = $arch64bit + ",`r`n" + $arch32bit
            $manifest = $manifest -replace "%architecture%", $architecture
        }
    }
    $manifest = $manifest -replace "%version%", $archHash['common']['version']
    $manifest = $manifest -replace "%langLabel%", $langLabelHash[$archHash['common']['lang']]
    $manifest = $manifest -replace "%majorVersion%", $archHash['common']['majorVersion']
    $manifest = $manifest -replace "%checkver_re%", $archHash['common']['checkver_re']

    #$manifest | Out-File -FilePath "$PSScriptRoot\..\$key.json" -Encoding utf8
    $manifest | Out-String `
        | % { [Text.Encoding]::UTF8.GetBytes($_) } `
        | Set-Content -Path "$PSScriptRoot\..\bucket\$key.json" -Encoding Byte
}

# Use scoop's checkver script to autoupdate the manifestHash
#& ./checkver.ps1 * -u
