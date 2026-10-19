using WaBiBaBuSy.Common.Diagnostics;
using Xunit;

namespace WaBiBaBuSy.Tests;

public class AppControlDiagnosticsTests
{
    [Theory]
    [InlineData(0, SmartAppControlState.Off)]
    [InlineData(1, SmartAppControlState.On)]
    [InlineData(2, SmartAppControlState.Evaluation)]
    [InlineData(7, SmartAppControlState.NotAvailable)]
    [InlineData(null, SmartAppControlState.NotAvailable)]
    public void RegistryValue_MapsToState(int? value, SmartAppControlState expected)
    {
        Assert.Equal(expected, AppControlDiagnostics.FromRegistryValue(value));
    }

    [Fact]
    public void PolicyBlockedFileLoad_IsDetected_EvenWhenWrapped()
    {
        var blocked = new FileLoadException("An Application Control policy has blocked this file.", @"C:\app\Avalonia.Base.dll")
        {
            HResult = AppControlDiagnostics.HResultPolicyBlocked
        };
        var wrapped = new TypeInitializationException("Avalonia.AppBuilder", blocked);

        Assert.True(AppControlDiagnostics.IsAppControlBlock(blocked));
        Assert.True(AppControlDiagnostics.IsAppControlBlock(wrapped));
        Assert.Equal(@"C:\app\Avalonia.Base.dll", AppControlDiagnostics.BlockedFile(wrapped));
    }

    [Fact]
    public void OtherFailures_AreNotReportedAsPolicyBlocks()
    {
        Assert.False(AppControlDiagnostics.IsAppControlBlock(new FileNotFoundException("missing", "x.dll")));
        Assert.False(AppControlDiagnostics.IsAppControlBlock(new InvalidOperationException("boom")));
        Assert.False(AppControlDiagnostics.IsAppControlBlock(null));
    }

    [Theory]
    [InlineData("Unhandled exception. System.IO.FileLoadException: Could not load file or assembly 'Vortice.Direct2D1.dll'. An Application Control policy has blocked this file. (0x800711C7)", true)]
    [InlineData("12:00:01 info: Program[0] D2DPlayer starting", false)]
    [InlineData(null, false)]
    public void PlayerStderr_PolicyBlockLineIsRecognized(string? line, bool expected)
    {
        Assert.Equal(expected, AppControlDiagnostics.IsAppControlBlockMessage(line));
    }
}
