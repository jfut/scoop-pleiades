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
        "re": "Pleiades All in One ((?<fileVersion>[\\d.]+).*\\.v(?<date>[\\d]+))"
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
        "64bit": {
            "url": "%64bit-url%#/dl.7z",
            "hash": "%64bit-hash%"
        },
        "32bit": {
            "url": "%32bit-url%#/dl.7z",
            "hash": "%32bit-hash%"
        }
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
        "re": "Pleiades All in One ((?<fileVersion>[\\d.]+).*\\.v(?<date>[\\d]+))"
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
$versionMatch = ([regex]">(4[\d.]+)/").matches($html)
$majorVersions = @()
$versionMatch |% {
    $majorVersions += $_.groups[1].value
}
# debug
#$majorVersions = $("4.2")
#$majorVersions = $("4.5", "4.6", "4.7")

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
        if ($majorVersion -ge "4.6") {
            $arch = "noarch"
        } else {
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
        $versionHtml = $wc.downloadstring("$baseVersionUrl$majorVersion.html")
        if ($versionHtml -match "Pleiades All in One (?<version>[\d.]+.*\.v[\d]+)") {
            $version = $matches['version']
        }
        #write-host " - version, $version"

        # Fetch file name and hash
        $downloadUrl = "$baseUrl$majorVersion/$link"
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
            })
            $archHash.add($arch, @{
                url = "$baseDownloadUrl$downloadFile";
                hash = $hash
            })
            $manifestHash.add($key, $archHash)
        }
        write-host ""
    }
}

# pleiades-java-win-full.json
# pleiades47-java-win-full.json
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
        $manifest = $manifest -replace "%64bit-url%", $archHash['64bit']['url']
        $hash = $archHash['64bit']['hash']
        if ($hash -eq $null) {
            $manifest = $manifest -replace ",\r\n.*%64bit-hash%.*\r\n", "`r`n"
        } else {
            $manifest = $manifest -replace "%64bit-hash%", $archHash['64bit']['hash']
        }
        $manifest = $manifest -replace "%32bit-url%", $archHash['32bit']['url']
        $hash = $archHash['32bit']['hash']
        if ($hash -eq $null) {
            $manifest = $manifest -replace ",\r\n.*%32bit-hash%.*\r\n", "`r`n"
        } else {
            $manifest = $manifest -replace "%32bit-hash%", $hash
        }
    }
    $manifest = $manifest -replace "%version%", $archHash['common']['version']
    $manifest = $manifest -replace "%langLabel%", $langLabelHash[$archHash['common']['lang']]
    $manifest = $manifest -replace "%majorVersion%", $archHash['common']['majorVersion']

    $manifest | Out-File -FilePath "$PSScriptRoot\..\$key.json" -Encoding utf8
}

# Use scoop's checkver script to autoupdate the manifestHash
#& ./checkver.ps1 * -u
