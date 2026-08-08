$Root = $PSScriptRoot

# ==========================================
# FIND DUPLICATE FILES
# ==========================================

$Files = @(
    Get-ChildItem -LiteralPath $Root -File -Recurse |
    Where-Object {
        $_.Name -match '\(\d+\)$' -or
        $_.BaseName -match ' - Copy(\s+\(\d+\))?$'
    }
)

Write-Host ""
Write-Host "=========================================="
Write-Host "       DUPLICATE FILE REVIEW"
Write-Host "=========================================="
Write-Host ""
Write-Host "Scanning:"
Write-Host $Root
Write-Host ""

if ($Files.Count -eq 0) {
    Write-Host "No duplicate files found."
    Read-Host "Press ENTER to exit"
    exit
}

Write-Host "Detected files:"
Write-Host ""

$Files | ForEach-Object {
    Write-Host $_.FullName
}

Write-Host ""
Write-Host "Total detected: $($Files.Count)"
Write-Host ""

# ==========================================
# WINDOWS EXPLORER MULTI-SELECTION
# ==========================================

Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ExplorerSelector
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr ILCreateFromPath(string path);

    [DllImport("shell32.dll")]
    public static extern IntPtr ILFindLastID(IntPtr pidl);

    [DllImport("shell32.dll")]
    public static extern int SHOpenFolderAndSelectItems(
        IntPtr pidlFolder,
        uint cidl,
        IntPtr[] apidl,
        uint dwFlags
    );

    [DllImport("shell32.dll")]
    public static extern void ILFree(IntPtr pidl);
}
"@

# ==========================================
# GROUP FILES BY THEIR FOLDER
# ==========================================

$Groups = $Files | Group-Object DirectoryName

Write-Host ""
Write-Host "Opening Explorer folders..."
Write-Host ""

foreach ($Group in $Groups)
{
    $FolderPath = $Group.Name

    Write-Host "Opening:"
    Write-Host "  $FolderPath"
    Write-Host "  Files selected: $($Group.Count)"
    Write-Host ""

    $FolderPIDL = [ExplorerSelector]::ILCreateFromPath($FolderPath)

    if ($FolderPIDL -eq [IntPtr]::Zero)
    {
        Write-Host "Could not open folder."
        continue
    }

    $FilePIDLs = New-Object IntPtr[] $Group.Count
    $AllPIDLs = @()

    $i = 0

    foreach ($File in $Group.Group)
    {
        $FullPIDL = [ExplorerSelector]::ILCreateFromPath($File.FullName)

        if ($FullPIDL -ne [IntPtr]::Zero)
        {
            $ChildPIDL = [ExplorerSelector]::ILFindLastID($FullPIDL)

            $FilePIDLs[$i] = $ChildPIDL

            $AllPIDLs += $FullPIDL

            $i++
        }
    }

    if ($i -gt 0)
    {
        [ExplorerSelector]::SHOpenFolderAndSelectItems(
            $FolderPIDL,
            [uint32]$i,
            $FilePIDLs,
            0
        )
    }

    foreach ($PIDL in $AllPIDLs)
    {
        [ExplorerSelector]::ILFree($PIDL)
    }

    [ExplorerSelector]::ILFree($FolderPIDL)

    Start-Sleep -Milliseconds 500
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Review windows opened."
Write-Host "=========================================="
Write-Host ""
Write-Host "Nothing has been deleted."
Write-Host ""

Read-Host "Press ENTER to exit"