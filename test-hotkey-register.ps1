# Quick test of hotkey registration
Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class TestHotkey {
    [DllImport("user32.dll")]
    public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    public static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    public const uint MOD_ALT = 0x0001;
    public const uint MOD_CONTROL = 0x0002;
    public const uint MOD_NOREPEAT = 0x4000;
    public const uint VK_L = 0x4C;
}
"@

Write-Host "Testing hotkey registration..." -ForegroundColor Cyan

# Create a hidden form to receive hotkey messages
$form = New-Object System.Windows.Forms.Form
$form.ShowInTaskbar = $false
$form.WindowState = [System.Windows.Forms.FormWindowState]::Minimized
$form.Visible = $false
$form.Show()
$form.Hide()

$mods = [TestHotkey]::MOD_CONTROL -bor [TestHotkey]::MOD_ALT -bor [TestHotkey]::MOD_NOREPEAT

# Test Ctrl+Alt+L
$result = [TestHotkey]::RegisterHotKey($form.Handle, 1, $mods, [TestHotkey]::VK_L)
Write-Host "Ctrl+Alt+L registration: $(if ($result) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($result) { 'Green' } else { 'Red' })

if ($result) {
    [TestHotkey]::UnregisterHotKey($form.Handle, 1)
    Write-Host "Unregistered successfully" -ForegroundColor Green
}

$form.Close()
$form.Dispose()
