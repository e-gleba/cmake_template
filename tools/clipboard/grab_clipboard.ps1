# Grab clipboard image on Windows and save as PNG.
param([Parameter(Mandatory=$true)][string]$OutPath)
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
if ([Windows.Forms.Clipboard]::ContainsImage()) {
    $img = [Windows.Forms.Clipboard]::GetImage()
    $img.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "Saved to $OutPath"
} else {
    Write-Error "No image on clipboard"
    exit 1
}
