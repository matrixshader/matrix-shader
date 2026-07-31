# Contributing to MatrixShader

Thanks for taking a look at MatrixShader. This repo is source-available and focused on GPU-powered terminal shader workflows for Windows Terminal and Linux/Ghostty.

## Before You Start

- Check existing issues before opening a duplicate.
- Open an issue before large changes, new platform ports, installer changes, or license-sensitive work.
- Keep pull requests focused on one fix, feature, shader, or documentation change.
- Do not include credentials, generated license keys, private dashboard URLs, or local machine paths.

## Development Setup

### Windows

1. Use Windows 10/11 with Windows Terminal.
2. Install the .NET SDK used by the repo.
3. Clone the repo.
4. Build with `dotnet build`.

### Linux

1. Review the Linux/Ghostty files in the repo before changing shader behavior.
2. Keep GLSL changes separate from Windows HLSL changes unless the feature is intentionally cross-platform.

## Code Style

- Follow the existing C# and shader patterns.
- Keep HLSL and GLSL shader parameters explicit and easy to tune.
- Avoid new dependencies unless they remove real operational complexity.
- Use present-tense commit messages, such as `Add teal preset`.

## Good Contributions

- New shader effects or visual refinements.
- GPU/vendor compatibility fixes.
- Windows Terminal profile handling improvements.
- Linux/Ghostty shader fixes.
- Clear screenshots, recordings, or reproduction notes for visual bugs.
- Documentation that helps users install, configure, or troubleshoot MatrixShader.

## Pull Requests

1. Fork the repo.
2. Create a focused branch.
3. Make the change.
4. Run the relevant build or manual verification.
5. Open a PR with what changed, why it matters, and how it was tested.

Visual changes should include screenshots or recordings when possible.
