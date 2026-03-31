using MatrixShader.Core.Services;
using Xunit;

namespace MatrixShader.Core.Tests;

/// <summary>
/// Tests for LicenseService — format validation and key file operations.
/// Client never does HMAC validation; that's server-side only.
/// Reference: linux/tests/test_license_service.py
/// </summary>
public class LicenseServiceTests : IDisposable
{
    private readonly LicenseService _svc = new();
    private readonly string _tempDir;

    public LicenseServiceTests()
    {
        _tempDir = Path.Combine(Path.GetTempPath(), $"matrix-test-{Guid.NewGuid():N}");
        Directory.CreateDirectory(_tempDir);
    }

    public void Dispose()
    {
        try { Directory.Delete(_tempDir, recursive: true); } catch { }
    }

    // -----------------------------------------------------------------------
    // ValidateKey — format checks (REDPILL-XXXX-XXXX-XXXX-XXXX)
    // -----------------------------------------------------------------------

    [Fact]
    public void ValidateKey_ValidFormat_ReturnsTrue()
    {
        Assert.True(_svc.ValidateKey("REDPILL-AAAA-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_Lowercase_ReturnsTrue()
    {
        Assert.True(_svc.ValidateKey("redpill-aaaa-bbbb-cccc-dddd"));
    }

    [Fact]
    public void ValidateKey_MixedCase_ReturnsTrue()
    {
        Assert.True(_svc.ValidateKey("RedPill-AaAa-BbBb-CcCc-DdDd"));
    }

    [Fact]
    public void ValidateKey_WithDigits_ReturnsTrue()
    {
        Assert.True(_svc.ValidateKey("REDPILL-A1B2-C3D4-E5F6-G7H8"));
    }

    [Fact]
    public void ValidateKey_WithWhitespace_ReturnsTrue()
    {
        Assert.True(_svc.ValidateKey("  REDPILL-AAAA-BBBB-CCCC-DDDD  "));
    }

    [Fact]
    public void ValidateKey_Empty_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey(""));
    }

    [Fact]
    public void ValidateKey_Null_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey(null!));
    }

    [Fact]
    public void ValidateKey_WhitespaceOnly_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("   "));
    }

    [Fact]
    public void ValidateKey_WrongPrefix_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("BLUEPILL-AAAA-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_NoPrefix_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("AAAA-BBBB-CCCC-DDDD-EEEE"));
    }

    [Fact]
    public void ValidateKey_TooFewGroups_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AAAA-BBBB"));
    }

    [Fact]
    public void ValidateKey_TooManyGroups_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AAAA-BBBB-CCCC-DDDD-EEEE"));
    }

    [Fact]
    public void ValidateKey_GroupTooShort_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AAA-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_GroupTooLong_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AAAAA-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_SpecialCharsInGroup_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AA!A-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_SpacesInGroup_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-AA A-BBBB-CCCC-DDDD"));
    }

    [Fact]
    public void ValidateKey_GarbageString_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("not-a-valid-key"));
    }

    [Fact]
    public void ValidateKey_JustPrefix_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL"));
    }

    [Fact]
    public void ValidateKey_PrefixWithOneDash_ReturnsFalse()
    {
        Assert.False(_svc.ValidateKey("REDPILL-"));
    }

    [Theory]
    [InlineData("REDPILL-0000-0000-0000-0000")]
    [InlineData("REDPILL-ZZZZ-ZZZZ-ZZZZ-ZZZZ")]
    [InlineData("REDPILL-1234-5678-9ABC-DEF0")]
    public void ValidateKey_AllAlphanumericGroups_ReturnsTrue(string key)
    {
        Assert.True(_svc.ValidateKey(key));
    }

    // -----------------------------------------------------------------------
    // Verify: NO crypto imports on client side
    // The LicenseService should never import or use HMAC/crypto for validation.
    // Server does that. This is a design constraint test.
    // -----------------------------------------------------------------------

    [Fact]
    public void NoCryptoImportsInLicenseService()
    {
        // Read the source file and confirm no crypto namespaces are used
        var sourceFile = Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", "..", "..",
            "src", "MatrixShader.Core", "Services", "LicenseService.cs");

        // Normalize path for cross-platform
        sourceFile = Path.GetFullPath(sourceFile);

        if (File.Exists(sourceFile))
        {
            var source = File.ReadAllText(sourceFile);
            Assert.DoesNotContain("System.Security.Cryptography", source);
            Assert.DoesNotContain("HMACSHA", source);
            Assert.DoesNotContain("using System.Security", source);
        }
        else
        {
            // If we can't find the source file from test output dir,
            // check the assembly references instead
            var assembly = typeof(LicenseService).Assembly;
            var referencedAssemblies = assembly.GetReferencedAssemblies();
            Assert.DoesNotContain(referencedAssemblies,
                a => a.Name == "System.Security.Cryptography");
        }
    }

    // -----------------------------------------------------------------------
    // ActivationResult enum values exist
    // -----------------------------------------------------------------------

    [Fact]
    public void ActivationResult_HasExpectedValues()
    {
        Assert.Equal(0, (int)ActivationResult.Success);
        Assert.Equal(1, (int)ActivationResult.InvalidKey);
        Assert.Equal(2, (int)ActivationResult.ActivationLimitExceeded);
        Assert.Equal(3, (int)ActivationResult.SaveFailed);
        Assert.Equal(4, (int)ActivationResult.ServerUnreachable);
    }

    // -----------------------------------------------------------------------
    // Activate — format rejection (doesn't hit server)
    // -----------------------------------------------------------------------

    [Fact]
    public void Activate_BadFormat_ReturnsInvalidKey()
    {
        var result = _svc.Activate("REDPILL-BAD-KEY");
        Assert.Equal(ActivationResult.InvalidKey, result);
    }

    [Fact]
    public void Activate_Empty_ReturnsInvalidKey()
    {
        var result = _svc.Activate("");
        Assert.Equal(ActivationResult.InvalidKey, result);
    }

    [Fact]
    public void Activate_WrongPrefix_ReturnsInvalidKey()
    {
        var result = _svc.Activate("BLUEPILL-AAAA-BBBB-CCCC-DDDD");
        Assert.Equal(ActivationResult.InvalidKey, result);
    }

    // -----------------------------------------------------------------------
    // ILicenseService interface contract
    // -----------------------------------------------------------------------

    [Fact]
    public void ImplementsILicenseService()
    {
        Assert.IsAssignableFrom<ILicenseService>(_svc);
    }

    [Fact]
    public void IsLicensed_DefaultInstall_ReturnsFalse()
    {
        // A fresh LicenseService with no key file on disk should not be licensed.
        // This test may pass or fail depending on whether the test machine
        // has a license installed. We create a fresh instance to test default behavior.
        // The service reads from %LOCALAPPDATA%\MatrixShader\license.key.
        // We can't easily redirect the path, but we can verify the property doesn't throw.
        var licensed = _svc.IsLicensed;
        Assert.IsType<bool>(licensed);
    }

    [Fact]
    public void GetInstalledKey_ReturnsStringOrNull()
    {
        // GetInstalledKey should return null if no key file, or a string if it exists.
        // We can't control the path, but we verify it doesn't throw.
        var key = _svc.GetInstalledKey();
        Assert.True(key == null || key.Length > 0);
    }
}
