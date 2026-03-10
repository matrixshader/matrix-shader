cask "matrix-shader" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/matrixshader/matrix-shader/releases/download/v#{version}/matrix-shader-mac-#{Hardware::CPU.arch}.tar.gz"
  name "Matrix Shader"
  desc "GPU-powered Matrix rain effects for your terminal"
  homepage "https://matrixshader.com"

  depends_on cask: "ghostty"

  preflight do
    system_command "/bin/mkdir", args: ["-p",
      "#{Dir.home}/.local/share/matrix-shader",
      "#{Dir.home}/.local/bin",
      "#{Dir.home}/.config/matrix-shader/shaders"]
  end

  artifact "matrix-shader", target: "#{Dir.home}/.local/share/matrix-shader"

  postflight do
    # Create wakeupneo symlink
    system_command "/bin/ln", args: ["-sf",
      "#{Dir.home}/.local/share/matrix-shader/mac/wakeupneo_mac.sh",
      "#{Dir.home}/.local/bin/wakeupneo"]

    # Make scripts executable
    system_command "/bin/chmod", args: ["+x",
      "#{Dir.home}/.local/share/matrix-shader/mac/wakeupneo_mac.sh",
      "#{Dir.home}/.local/share/matrix-shader/mac/matrix_keys_mac.py"]

    # macOS convention symlink
    system_command "/bin/ln", args: ["-sf",
      "#{Dir.home}/.config/matrix-shader",
      "#{Dir.home}/Library/Application Support/MatrixShader"]
  end

  uninstall delete: [
    "#{Dir.home}/.local/share/matrix-shader",
    "#{Dir.home}/.local/bin/wakeupneo",
    "#{Dir.home}/Library/Application Support/MatrixShader",
  ]

  zap trash: [
    "#{Dir.home}/.config/matrix-shader",
  ]

  caveats <<~EOS
    Matrix Shader needs Accessibility permission for global hotkeys.
    Grant access in: System Settings > Privacy & Security > Accessibility

    Make sure ~/.local/bin is in your PATH:
      export PATH="$HOME/.local/bin:$PATH"

    To start: run 'wakeupneo' in your terminal.
  EOS
end
