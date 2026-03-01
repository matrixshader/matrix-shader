# Testing Matrix Shader

## Windows Sandbox Testing

Use the `.wsb` config to test in an isolated Windows Sandbox environment.

```xml
<Configuration>
  <VGpu>Enable</VGpu>
  <Networking>Enable</Networking>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\path\to\matrix-shader\installer\output</HostFolder>
      <SandboxFolder>C:\Installer</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
</Configuration>
```

Update `HostFolder` to your actual path.

## Test Checklist

1. Run installer from sandbox
2. Verify `wakeupneo` launches correctly
3. Test Blue Pill and Red Pill paths
4. Verify hotkeys (Ctrl+B transparency, Ctrl+Shift+arrows rotation)
5. Test Glitch snap positioning
6. Verify uninstaller removes all files and registry entries
