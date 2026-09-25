<#
.SYNOPSIS
  Resolve, deploy and verify the Windows runtime DLL closure of an install tree.

.DESCRIPTION
  Walks the PE import tables (regular and delay-load) of every PE file under
  -Root and classifies each imported DLL as:

    bundled  - present inside the payload tree already
    system   - provided by Windows itself (System32 / SysWOW64 / known OS API sets)
    resolved - found in one of the -SearchDir locations
    missing  - required but not found anywhere -> hard failure

  Every PE file in the tree must also match -ExpectedArch; a wrong-architecture
  payload is a hard failure. In -Deploy mode a wrong-architecture bundled file
  is repaired when a correctly built same-named file exists in the search
  directories, and dropped when nothing imports it; otherwise the run fails.

  A JSON report is always written so CI can upload it as evidence, including
  on failure.

  Design notes
  ------------
  * file(GET_RUNTIME_DEPENDENCIES) was rejected: on Windows it requires
    objdump/dumpbin on PATH at install time (unavailable on MSVC legs) and it
    only follows CMake target-level dependencies, which does not cover raw
    FindwxWidgets paths.
  * X_VCPKG_APPLOCAL_DEPS_INSTALL was researched and rejected: experimental,
    and it only wires vcpkg-installed DLLs into install() for targets that
    link imported CMake targets.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,

    # x86_64 | i686 | arm64
    [Parameter(Mandatory = $true)]
    [ValidateSet('x86_64', 'i686', 'arm64')]
    [string]$ExpectedArch,

    [string[]]$SearchDir = @(),

    # Copy/repair resolved dependencies inside the payload instead of only reporting.
    [switch]$Deploy,

    # Report-only forensics mode: never throw, just write the report.
    [switch]$ReportOnly,

    [string]$Report
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function Get-PEInfo {
    param([string]$Path)
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
    } catch {
        return $null
    }
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) { return $null }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
    if ($peOffset -lt 0 -or ($peOffset + 24) -gt $bytes.Length) { return $null }
    if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or
        $bytes[$peOffset + 2] -ne 0x00 -or $bytes[$peOffset + 3] -ne 0x00) { return $null }

    $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    $numberOfSections = [BitConverter]::ToUInt16($bytes, $peOffset + 6)
    $sizeOfOptionalHeader = [BitConverter]::ToUInt16($bytes, $peOffset + 20)
    $optOffset = $peOffset + 24
    $magic = [BitConverter]::ToUInt16($bytes, $optOffset)
    if ($magic -eq 0x20B) { $ddOffset = $optOffset + 112 }
    elseif ($magic -eq 0x10B) { $ddOffset = $optOffset + 96 }
    else { return @{ Machine = $machine; Imports = @() } }

    $sections = @()
    for ($i = 0; $i -lt $numberOfSections; $i++) {
        $so = $optOffset + $sizeOfOptionalHeader + ($i * 40)
        if (($so + 40) -gt $bytes.Length) { break }
        $virtualSize = [BitConverter]::ToUInt32($bytes, $so + 8)
        $virtualAddress = [BitConverter]::ToUInt32($bytes, $so + 12)
        $rawSize = [BitConverter]::ToUInt32($bytes, $so + 16)
        $rawPointer = [BitConverter]::ToUInt32($bytes, $so + 20)
        $sections += ,@($virtualAddress, $virtualSize, $rawPointer, $rawSize)
    }

    $imports = [System.Collections.Generic.List[string]]::new()

    # Data directory 1: import table
    if (($ddOffset + 16) -le $bytes.Length) {
        $importRva = [BitConverter]::ToUInt32($bytes, $ddOffset + 8)
        if ($importRva -ne 0) {
            $off = Convert-RvaToOffset $bytes $sections $importRva
            while ($off -ge 0 -and ($off + 20) -le $bytes.Length) {
                $allZero = $true
                for ($k = 0; $k -lt 20; $k++) { if ($bytes[$off + $k] -ne 0) { $allZero = $false; break } }
                if ($allZero) { break }
                $nameRva = [BitConverter]::ToUInt32($bytes, $off + 12)
                $name = Read-AsciiCString $bytes (Convert-RvaToOffset $bytes $sections $nameRva)
                if ($name) { $imports.Add($name) }
                $off += 20
            }
        }
    }

    # Data directory 13: delay import table
    if (($ddOffset + 112) -le $bytes.Length) {
        $delayRva = [BitConverter]::ToUInt32($bytes, $ddOffset + 104)
        if ($delayRva -ne 0) {
            $off = Convert-RvaToOffset $bytes $sections $delayRva
            while ($off -ge 0 -and ($off + 32) -le $bytes.Length) {
                $allZero = $true
                for ($k = 0; $k -lt 32; $k++) { if ($bytes[$off + $k] -ne 0) { $allZero = $false; break } }
                if ($allZero) { break }
                $attributes = [BitConverter]::ToUInt32($bytes, $off)
                $nameRva = [BitConverter]::ToUInt32($bytes, $off + 4)
                if (($attributes -band 1) -eq 0) {
                    $imageBase = if ($magic -eq 0x20B) { [BitConverter]::ToUInt64($bytes, $optOffset + 24) } else { [uint64][BitConverter]::ToUInt32($bytes, $optOffset + 28) }
                    if ($imageBase -gt 0 -and $nameRva -ge $imageBase) { $nameRva = [uint32]($nameRva - $imageBase) }
                }
                $name = Read-AsciiCString $bytes (Convert-RvaToOffset $bytes $sections $nameRva)
                if ($name) { $imports.Add($name) }
                $off += 32
            }
        }
    }

    return @{ Machine = $machine; Imports = $imports }
}

function Convert-RvaToOffset {
    param([byte[]]$Bytes, [array]$Sections, [uint32]$Rva)
    foreach ($s in $Sections) {
        $va = [uint32]$s[0]; $vs = [uint32]$s[1]; $raw = [uint32]$s[2]; $rs = [uint32]$s[3]
        $size = [Math]::Max($vs, $rs)
        if ($size -eq 0) { continue }
        if ($Rva -ge $va -and $Rva -lt ($va + $size)) {
            $off = [int64]$raw + [int64]($Rva - $va)
            if ($off -ge 0 -and $off -lt $Bytes.Length) { return [int]$off }
        }
    }
    return -1
}

function Read-AsciiCString {
    param([byte[]]$Bytes, [int]$Offset)
    if ($Offset -lt 0 -or $Offset -ge $Bytes.Length) { return $null }
    $end = $Offset
    while ($end -lt $Bytes.Length -and $Bytes[$end] -ne 0) { $end++ }
    if ($end -eq $Offset) { return $null }
    return [System.Text.Encoding]::ASCII.GetString($Bytes, $Offset, $end - $Offset)
}

function Get-ArchName {
    param([uint16]$Machine)
    switch ($Machine) {
        0x8664 { return 'x86_64' }
        0x014C { return 'i686' }
        0xAA64 { return 'arm64' }
        0x01C0 { return 'arm' }
        0x01C4 { return 'armnt' }
        default { return ('unknown-0x{0:X4}' -f $Machine) }
    }
}

$expectedMachine = switch ($ExpectedArch) {
    'x86_64' { [uint16]0x8664 }
    'i686'   { [uint16]0x014C }
    'arm64'  { [uint16]0xAA64 }
}

$systemDllPatterns = @(
    '^api-ms-win-.*\.dll$', '^ext-ms-win-.*\.dll$',
    '^ucrtbase.*\.dll$', '^msvcrt.*\.dll$', '^ntdll\.dll$', '^kernel32\.dll$', '^kernelbase\.dll$',
    '^user32\.dll$', '^gdi32\.dll$', '^gdiplus\.dll$', '^imm32\.dll$', '^msimg32\.dll$',
    '^advapi32\.dll$', '^shell32\.dll$', '^shlwapi\.dll$', '^shcore\.dll$', '^ole32\.dll$',
    '^oleaut32\.dll$', '^olepro32\.dll$', '^ws2_32\.dll$', '^wsock32\.dll$', '^comdlg32\.dll$',
    '^comctl32\.dll$', '^winspool\.drv$', '^setupapi\.dll$', '^version\.dll$', '^uxtheme\.dll$',
    '^oleacc\.dll$', '^rpcrt4\.dll$', '^dnsapi\.dll$', '^dbghelp\.dll$', '^psapi\.dll$',
    '^winmm\.dll$', '^avifil32\.dll$', '^msvfw32\.dll$', '^avicap32\.dll$', '^wldap32\.dll$',
    '^crypt32\.dll$', '^cryptui\.dll$', '^secur32\.dll$', '^ncrypt\.dll$', '^bcrypt\.dll$',
    '^userenv\.dll$', '^iphlpapi\.dll$', '^netapi32\.dll$', '^powrprof\.dll$', '^cfgmgr32\.dll$',
    '^opengl32\.dll$', '^dwmapi\.dll$', '^hid\.dll$', '^combase\.dll$', '^wintrust\.dll$',
    '^imagehlp\.dll$', '^msasn1\.dll$', '^winhttp\.dll$', '^wininet\.dll$', '^normaliz\.dll$',
    '^d3d9\.dll$', '^d3d11\.dll$', '^dxgi\.dll$', '^d2d1\.dll$', '^windowscodecs\.dll$',
    '^propsys\.dll$', '^wtsapi32\.dll$', '^winsta\.dll$', '^mpr\.dll$', '^samlib\.dll$',
    '^wkscli\.dll$', '^netutils\.dll$', '^srvcli\.dll$', '^browcli\.dll$', '^authz\.dll$',
    '^apphelp\.dll$', '^textshaping\.dll$', '^textinputframework\.dll$', '^coreuiming\.dll$',
    '^wpaxholder\.dll$', '^mpr\.dll$', '^winbrand\.dll$', '^dpapi\.dll$', '^cryptnet\.dll$'
)

# The MSVC C++ runtime DLLs are only "system" when Windows actually carries
# them; otherwise a build that does not bundle them must fail loudly.
$vcRuntimePatterns = @('^vcruntime.*\.dll$', '^msvcp.*\.dll$', '^concrt140.*\.dll$', '^msvcr.*\.dll$')

$systemDirs = @()
foreach ($d in @("$env:SystemRoot\System32", "$env:SystemRoot\SysWOW64", "$env:SystemRoot\Sysnative")) {
    if ($d -and (Test-Path -LiteralPath $d)) { $systemDirs += $d }
}

function Test-SystemDll {
    param([string]$Name)
    $n = $Name.ToLowerInvariant()
    foreach ($p in $systemDllPatterns) { if ($n -match $p) { return $true } }
    foreach ($p in $vcRuntimePatterns) {
        if ($n -match $p) {
            foreach ($d in $systemDirs) { if (Test-Path -LiteralPath (Join-Path $d $Name)) { return $true } }
            return $false
        }
    }
    return $false
}

if (-not (Test-Path -LiteralPath $Root)) {
    throw "Payload root not found: $Root"
}
$Root = (Resolve-Path -LiteralPath $Root).Path

$searchPaths = [System.Collections.Generic.List[string]]::new()
foreach ($s in $SearchDir) {
    if ($s -and (Test-Path -LiteralPath $s)) {
        $rp = (Resolve-Path -LiteralPath $s).Path
        if (-not $searchPaths.Contains($rp)) { $searchPaths.Add($rp) }
    }
}
# Always search the process PATH too (covers MSYS2 prefixes added by CI).
foreach ($p in ($env:PATH -split [IO.Path]::PathSeparator)) {
    if ($p -and (Test-Path -LiteralPath $p)) {
        $rp = (Resolve-Path -LiteralPath $p).Path
        if (-not $searchPaths.Contains($rp)) { $searchPaths.Add($rp) }
    }
}

function Get-SearchHit {
    param([string]$Name)
    foreach ($sp in $searchPaths) {
        $candidate = Join-Path $sp $Name
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    return $null
}

$payload = @{}
$queue = [System.Collections.Generic.Queue[string]]::new()
$seen = @{}
$records = [System.Collections.Generic.List[object]]::new()
$missing = [System.Collections.Generic.List[object]]::new()
$missingNames = @{}
$importedBy = @{}
$deployed = @()
$repaired = [System.Collections.Generic.List[object]]::new()
$removed = [System.Collections.Generic.List[object]]::new()
$archMismatch = [System.Collections.Generic.List[object]]::new()

$allFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue)
foreach ($f in $allFiles) { $payload[$f.Name.ToLowerInvariant()] = $f.FullName }

function Add-ToQueue {
    param([string]$Path)
    $key = $Path.ToLowerInvariant()
    if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $queue.Enqueue($Path) }
}

foreach ($f in $allFiles) {
    $info = Get-PEInfo -Path $f.FullName
    if ($null -eq $info) { continue }
    Add-ToQueue -Path $f.FullName
}

while ($queue.Count -gt 0) {
    $file = $queue.Dequeue()
    $info = Get-PEInfo -Path $file
    if ($null -eq $info) { continue }
    $arch = Get-ArchName -Machine ([uint16]$info.Machine)
    $rel = $file.Substring($Root.Length).TrimStart('\', '/')

    $importRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($dll in ($info.Imports | Select-Object -Unique)) {
        $lower = $dll.ToLowerInvariant()
        if (-not $importedBy.ContainsKey($lower)) { $importedBy[$lower] = @() }
        $importedBy[$lower] += $rel

        $classification = $null
        $resolvedFrom = $null

        if ($payload.ContainsKey($lower)) {
            $classification = 'bundled'
            Add-ToQueue -Path $payload[$lower]
        } elseif (Test-SystemDll -Name $dll) {
            $classification = 'system'
        } else {
            $hit = Get-SearchHit -Name $dll
            if ($hit) {
                $resolvedInfo = Get-PEInfo -Path $hit
                if ($null -ne $resolvedInfo -and [uint16]$resolvedInfo.Machine -eq $expectedMachine) {
                    $classification = 'resolved'
                    $resolvedFrom = $hit
                }
            }
            if (-not $classification) {
                $classification = 'missing'
            }
        }

        if ($classification -eq 'resolved') {
            if ($Deploy) {
                $dest = Join-Path (Split-Path -Parent $file) $dll
                Copy-Item -LiteralPath $resolvedFrom -Destination $dest -Force
                $deployed += $dll
                $payload[$lower] = $dest
                $importRecords.Add([pscustomobject]@{ name = $dll; classification = 'bundled'; resolvedFrom = $resolvedFrom })
                Add-ToQueue -Path $dest
                continue
            } else {
                # Present on the build host but not shippable in this payload.
                $classification = 'missing'
                if (-not $missingNames.ContainsKey($lower)) {
                    $missingNames[$lower] = $true
                    $missing.Add([pscustomobject]@{
                        name = $dll; importedBy = $rel; foundAt = $resolvedFrom
                        reason = 'present on build host but not bundled into the payload'
                    })
                }
            }
        }

        if ($classification -eq 'missing' -and -not $missingNames.ContainsKey($lower)) {
            $missingNames[$lower] = $true
            $missing.Add([pscustomobject]@{
                name = $dll; importedBy = $rel; foundAt = $null
                reason = 'not found in payload, OS or search paths'
            })
        }

        $importRecords.Add([pscustomobject]@{ name = $dll; classification = $classification; resolvedFrom = $resolvedFrom })
    }

    if ([uint16]$info.Machine -ne $expectedMachine) {
        $archMismatch.Add($file)
    }

    $records.Add([pscustomobject]@{
        path = $rel
        machine = $arch
        expectedArch = $ExpectedArch
        archOk = ([uint16]$info.Machine -eq $expectedMachine)
        imports = @($importRecords)
    })
}

# ---------------------------------------------------------------------------
# Wrong-architecture payload repair (deploy) / rejection (verify)
# ---------------------------------------------------------------------------
$unresolvedArch = [System.Collections.Generic.List[object]]::new()
foreach ($bad in $archMismatch) {
    $name = Split-Path -Leaf $bad
    $rel = $bad.Substring($Root.Length).TrimStart('\', '/')
    $current = Get-PEInfo -Path $bad
    $currentArch = Get-ArchName -Machine ([uint16]$current.Machine)

    $replacement = $null
    $hit = Get-SearchHit -Name $name
    if ($hit) {
        $hitInfo = Get-PEInfo -Path $hit
        if ($null -ne $hitInfo -and [uint16]$hitInfo.Machine -eq $expectedMachine) { $replacement = $hit }
    }

    $inUse = $importedBy.ContainsKey($name.ToLowerInvariant())

    if ($Deploy -and $replacement) {
        Copy-Item -LiteralPath $replacement -Destination $bad -Force
        $repaired.Add([pscustomobject]@{ path = $rel; from = $currentArch; replacedWith = $replacement })
        $payload[$name.ToLowerInvariant()] = $bad
        Add-ToQueue -Path $bad
    } elseif ($Deploy -and -not $inUse) {
        Remove-Item -LiteralPath $bad -Force
        $removed.Add([pscustomobject]@{ path = $rel; machine = $currentArch; reason = 'wrong architecture and not imported by any payload binary' })
        $payload.Remove($name.ToLowerInvariant())
    } else {
        $unresolvedArch.Add([pscustomobject]@{
            path = $rel; machine = $currentArch; expected = $ExpectedArch
            importedBy = $(if ($inUse) { @($importedBy[$name.ToLowerInvariant()]) } else { @() })
            replacementFound = [bool]$replacement
        })
    }
}

$ok = ($missing.Count -eq 0) -and ($unresolvedArch.Count -eq 0)

$reportObject = [pscustomobject]@{
    schema = 'cpp-project-template.windows-runtime-dependencies.v1'
    root = $Root
    expectedArch = $ExpectedArch
    mode = $(if ($Deploy) { 'deploy' } else { 'verify' })
    deployed = @($deployed | Sort-Object -Unique)
    repaired = @($repaired)
    removed = @($removed)
    counts = [pscustomobject]@{
        files = $records.Count
        missing = $missing.Count
        archMismatch = $unresolvedArch.Count
    }
    missing = @($missing)
    archMismatch = @($unresolvedArch)
    files = @($records | Sort-Object path)
    ok = $ok
}

if ($Report) {
    $reportDir = Split-Path -Parent $Report
    if ($reportDir -and -not (Test-Path -LiteralPath $reportDir)) {
        New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    }
    $reportObject | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Report -Encoding UTF8
}

if (-not $ok) {
    foreach ($m in $missing) {
        Write-Host ("MISSING {0} (imported by {1})" -f $m.name, $m.importedBy)
    }
    foreach ($a in $unresolvedArch) {
        Write-Host ("ARCH    {0}: got {1}, expected {2}" -f $a.path, $a.machine, $a.expected)
    }
    if (-not $ReportOnly) {
        throw ("Windows runtime dependency verification failed: {0} missing, {1} architecture mismatch(es). Report: {2}" -f $missing.Count, $unresolvedArch.Count, $Report)
    }
}

Write-Host ("Windows runtime dependency verification passed: {0} PE file(s), {1} missing, {2} arch mismatch(es), {3} deployed, {4} repaired, {5} removed." -f `
    $records.Count, $missing.Count, $unresolvedArch.Count, @($deployed).Count, @($repaired).Count, @($removed).Count)
