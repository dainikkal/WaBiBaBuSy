using Microsoft.Win32;

namespace WaBiBaBuSy.Common.Diagnostics;

/// <summary>State of Windows 11 Smart App Control (same values as <c>Get-MpComputerStatus</c>).</summary>
public enum SmartAppControlState
{
    /// <summary>Not present (Windows 10, older Windows 11, non-Windows) or unreadable.</summary>
    NotAvailable,
    Off,
    On,
    /// <summary>Evaluation mode: not blocking yet, but Windows may switch it to On by itself.</summary>
    Evaluation
}

/// <summary>
/// Detects Windows Application Control (Smart App Control / WDAC) blocking our unsigned binaries.
/// A blocked Avalonia DLL kills the app before any window exists, so this has no Avalonia dependency
/// and reports through a plain log file (<see cref="WriteStartupReport"/>).
/// </summary>
public static class AppControlDiagnostics
{
    private const string PolicyKey = @"SYSTEM\CurrentControlSet\Control\CI\Policy";
    private const string PolicyValue = "VerifiedAndReputablePolicyState";

    /// <summary>ERROR_SYSTEM_INTEGRITY_POLICY_VIOLATION as HRESULT: "An Application Control policy has blocked this file".</summary>
    public const int HResultPolicyBlocked = unchecked((int)0x800711C7);

    private static readonly Lazy<SmartAppControlState> s_state = new(ReadState);

    /// <summary>Smart App Control state of this machine (read once).</summary>
    public static SmartAppControlState SmartAppControl => s_state.Value;

    /// <summary>True when Smart App Control may block unsigned files (On, or Evaluation which can turn On).</summary>
    public static bool MayBlockUnsignedCode => SmartAppControl is SmartAppControlState.On or SmartAppControlState.Evaluation;

    private static SmartAppControlState ReadState()
    {
        if (!OperatingSystem.IsWindows()) return SmartAppControlState.NotAvailable;
        try
        {
            using var key = Registry.LocalMachine.OpenSubKey(PolicyKey);
            return FromRegistryValue(key?.GetValue(PolicyValue) as int?);
        }
        catch (Exception)
        {
            return SmartAppControlState.NotAvailable;
        }
    }

    /// <summary>Maps the <c>VerifiedAndReputablePolicyState</c> registry value (0 Off, 1 On, 2 Evaluation).</summary>
    public static SmartAppControlState FromRegistryValue(int? value) => value switch
    {
        0 => SmartAppControlState.Off,
        1 => SmartAppControlState.On,
        2 => SmartAppControlState.Evaluation,
        _ => SmartAppControlState.NotAvailable
    };

    /// <summary>True if <paramref name="ex"/> (or an inner exception) is Windows refusing to load a file by policy.</summary>
    public static bool IsAppControlBlock(Exception? ex)
    {
        for (var e = ex; e != null; e = e.InnerException)
        {
            if (e.HResult == HResultPolicyBlocked)
                return true;
        }
        return false;
    }

    /// <summary>True if a line of player stderr (an unhandled-exception dump) reports a policy block.</summary>
    public static bool IsAppControlBlockMessage(string? line) =>
        line != null
        && (line.Contains("0x800711C7", StringComparison.OrdinalIgnoreCase)
            || line.Contains("Application Control policy has blocked", StringComparison.OrdinalIgnoreCase));

    /// <summary>The blocked file path from a policy-block exception, if present.</summary>
    public static string? BlockedFile(Exception? ex)
    {
        for (var e = ex; e != null; e = e.InnerException)
            if (e is FileLoadException fle && !string.IsNullOrEmpty(fle.FileName))
                return fle.FileName;
        return null;
    }

    /// <summary>One-line state for logs, e.g. "Smart App Control: On".</summary>
    public static string StatusLine() => $"Smart App Control: {SmartAppControl}";

    /// <summary>What to do about a block, for message boxes and the control panel.</summary>
    public const string HowToFix =
        "Windows Security > App & browser control > Smart App Control settings > Off. " +
        "(On some Windows 11 versions it cannot be switched back on without resetting Windows.) " +
        "On a work/school PC an admin-managed policy (WDAC) may be responsible instead.";

    /// <summary>Path of the startup log (written before the normal logger exists).</summary>
    public static string StartupLogPath => Path.Combine(PathHelper.GetLogsPath(), "startup.log");

    /// <summary>Append a timestamped line to <see cref="StartupLogPath"/>. Never throws.</summary>
    public static void WriteStartupReport(string message)
    {
        try
        {
            File.AppendAllText(StartupLogPath,
                $"{DateTime.Now:yyyy-MM-dd HH:mm:ss} {message}{Environment.NewLine}");
        }
        catch (Exception)
        {
            // Diagnostics must never take the app down
        }
    }
}
