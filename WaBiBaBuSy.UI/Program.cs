using Avalonia;
using Avalonia.Win32;
using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using WaBiBaBuSy.Common.Diagnostics;

namespace WaBiBaBuSy.UI;

sealed class Program
{
    // Initialization code. Don't use any Avalonia, third-party APIs or any
    // SynchronizationContext-reliant code before AppMain is called: things aren't initialized
    // yet and stuff might break.
    [STAThread]
    public static int Main(string[] args)
    {
        CliConsole.Initialize();
        // Before anything touches Avalonia: if Smart App Control blocks an unsigned DLL the app dies
        // without a window, so the state goes to a plain log file first.
        AppControlDiagnostics.WriteStartupReport($"Starting WaBiBaBuSy UI ({AppControlDiagnostics.StatusLine()})");
        // One instance per user session: a second one would kill the first one's players at startup
        // (orphan cleanup), fight over the server port and the hotkeys, and repaint the desktop.
        using var instance = new System.Threading.Mutex(initiallyOwned: true, SingleInstanceMutexName, out bool firstInstance);
        if (!firstInstance)
        {
            CliConsole.WriteLine("WaBiBaBuSy is already running (tray icon). Close it first, or run tests from its Developer tools.", error: true);
            return 2;   // = "could not run" for --test-run --exit
        }
        var options = StartupOptions.Parse(args);
        foreach (var warning in options.Warnings)
            CliConsole.WriteLine($"WaBiBaBuSy: {warning} ({StartupOptions.Usage})", error: true);
        // Never block automated runs with a dialog
        bool interactive = options.TestRunPath == null;
        try
        {
            // The lifetime returns the code passed to Shutdown(): --test-run --exit relies on it (0 / 1 / 2).
            return RunAvalonia(args);
        }
        catch (Exception ex) when (AppControlDiagnostics.IsAppControlBlock(ex))
        {
            var file = AppControlDiagnostics.BlockedFile(ex) ?? "one of its files";
            AppControlDiagnostics.WriteStartupReport($"BLOCKED by Windows Application Control: {file}{Environment.NewLine}{ex}");
            var text = $"Windows blocked WaBiBaBuSy from loading:\n{file}\n\n{AppControlDiagnostics.StatusLine()}\n\n"
                     + $"How to fix: {AppControlDiagnostics.HowToFix}\n\nLog: {AppControlDiagnostics.StartupLogPath}";
            CliConsole.WriteLine(text.Replace("\n\n", " ").Replace("\n", " "), error: true);
            if (interactive) ShowError(text);
            return 2;   // = "could not run"
        }
        catch (Exception ex)
        {
            AppControlDiagnostics.WriteStartupReport($"CRASH ({AppControlDiagnostics.StatusLine()}){Environment.NewLine}{ex}");
            if (interactive)
                ShowError($"WaBiBaBuSy stopped because of an error:\n{ex.GetType().Name}: {ex.Message}\n\nDetails: {AppControlDiagnostics.StartupLogPath}");
            throw;
        }
    }

    // Kept out of Main: JIT-compiling Main must not load Avalonia, or a blocked Avalonia DLL fails
    // before the try/catch above can report it.
    [MethodImpl(MethodImplOptions.NoInlining)]
    private static int RunAvalonia(string[] args) => BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int MessageBoxW(IntPtr hWnd, string text, string caption, uint type);

    private static void ShowError(string text)
    {
        const uint MbOk = 0x0, MbIconError = 0x10, MbSetForeground = 0x10000;
        try { MessageBoxW(IntPtr.Zero, text, "WaBiBaBuSy", MbOk | MbIconError | MbSetForeground); }
        catch (Exception) { /* no UI available — the startup log has it */ }
    }

    /// <summary>Per-session (Local\) name; also usable as the installer's AppMutex.</summary>
    public const string SingleInstanceMutexName = @"Local\WaBiBaBuSy.UI";

    // Avalonia configuration, don't remove; also used by visual designer.
    public static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace()
            // GPU Optimization: Use software rendering backend to reduce GPU load
            // This trades GPU usage for slightly higher CPU usage, but results in more predictable performance
            // Can be toggled by setting environment variable AVALONIA_RENDER_MODE=software or removing this line
            .With(new Win32PlatformOptions
            {
                RenderingMode = new[] { Win32RenderingMode.Software, Win32RenderingMode.AngleEgl }
            });
}
