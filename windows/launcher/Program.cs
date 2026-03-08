using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("IOPaint Launcher")]
[assembly: AssemblyProduct("IOPaint Launcher")]
[assembly: AssemblyDescription("Launches IOPaint as a tray-controlled background app.")]
[assembly: AssemblyCompany("OpenAI Codex")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class Program
{
    private const string SingleInstanceMutexName = "IOPaintLauncherTrayMutex";
    private const string DefaultUrl = "http://127.0.0.1:8080/";

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string startScriptPath = Path.Combine(root, "windows", "start-iopaint.ps1");
            string stopScriptPath = Path.Combine(root, "windows", "stop-iopaint.ps1");
            if (!File.Exists(startScriptPath))
            {
                return Fail("Missing launcher script:\n" + startScriptPath, 2);
            }

            if (!File.Exists(stopScriptPath))
            {
                return Fail("Missing stop script:\n" + stopScriptPath, 6);
            }

            string shellPath = FindExecutable("pwsh.exe");
            if (string.IsNullOrEmpty(shellPath))
            {
                shellPath = FindExecutable("powershell.exe");
            }

            if (string.IsNullOrEmpty(shellPath))
            {
                return Fail("PowerShell was not found on this system.", 3);
            }

            if (args.Length == 1 && string.Equals(args[0], "--launcher-self-test", StringComparison.OrdinalIgnoreCase))
            {
                return 0;
            }

            if (args.Length == 1 && string.Equals(args[0], "--stop", StringComparison.OrdinalIgnoreCase))
            {
                string stopOutput;
                string stopError;
                if (!RunHiddenPowerShell(shellPath, BuildPowerShellArguments(stopScriptPath, new string[0]), root, out stopOutput, out stopError))
                {
                    return Fail(BuildFailureMessage("Failed to stop IOPaint.", stopOutput, stopError), 5);
                }

                return 0;
            }

            bool createdNew;
            using (Mutex mutex = new Mutex(true, SingleInstanceMutexName, out createdNew))
            {
                if (!createdNew)
                {
                    OpenUrl(DefaultUrl);
                    return 0;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                using (LauncherApplicationContext context = new LauncherApplicationContext(root, shellPath, startScriptPath, stopScriptPath, args))
                {
                    Application.Run(context);
                    return context.ExitCode;
                }
            }
        }
        catch (Exception ex)
        {
            return Fail("Unexpected launcher error:\n" + ex.Message, 1);
        }
    }

    private sealed class LauncherApplicationContext : ApplicationContext
    {
        private readonly string root;
        private readonly string shellPath;
        private readonly string stopScriptPath;
        private readonly Control uiInvoker;
        private readonly NotifyIcon notifyIcon;
        private readonly System.Windows.Forms.Timer monitorTimer;
        private readonly ToolStripMenuItem openMenuItem;
        private int backendPid;
        private string webUrl;

        internal int ExitCode { get; private set; }

        internal LauncherApplicationContext(string root, string shellPath, string startScriptPath, string stopScriptPath, string[] launchArgs)
        {
            this.root = root;
            this.shellPath = shellPath;
            this.stopScriptPath = stopScriptPath;
            this.webUrl = DefaultUrl;
            this.ExitCode = 0;
            this.uiInvoker = new Control();
            IntPtr ignoreHandle = this.uiInvoker.Handle;

            ToolStripMenuItem openMenuItem;
            this.notifyIcon = CreateNotifyIcon(out openMenuItem);
            this.openMenuItem = openMenuItem;
            this.monitorTimer = new System.Windows.Forms.Timer();
            this.monitorTimer.Interval = 3000;
            this.monitorTimer.Tick += OnMonitorTimerTick;
            this.monitorTimer.Start();
            ThreadPool.QueueUserWorkItem(delegate(object state)
            {
                StartBackendAsync(startScriptPath, launchArgs);
            });
        }

        private void StartBackendAsync(string startScriptPath, string[] launchArgs)
        {
            string output;
            string error;
            if (!RunHiddenPowerShell(this.shellPath, BuildStartArguments(startScriptPath, launchArgs), this.root, out output, out error))
            {
                PostToUi(delegate
                {
                    this.ExitCode = 4;
                    MessageBox.Show(
                        BuildFailureMessage("Failed to start the IOPaint background process.", output, error),
                        "IOPaint Launcher",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    ExitThread();
                });
                return;
            }

            string parsedUrl = TryGetNamedValue(output, "URL");
            string parsedPid = TryGetNamedValue(output, "PID");
            int processId = 0;
            if (!string.IsNullOrEmpty(parsedPid))
            {
                int.TryParse(parsedPid, out processId);
            }

            PostToUi(delegate
            {
                if (!string.IsNullOrEmpty(parsedUrl))
                {
                    this.webUrl = parsedUrl;
                }

                if (processId > 0)
                {
                    this.backendPid = processId;
                }

                this.notifyIcon.Text = "IOPaint";
                this.openMenuItem.Enabled = true;
                OpenUrl(this.webUrl);
            });
        }

        private NotifyIcon CreateNotifyIcon(out ToolStripMenuItem openItem)
        {
            ContextMenuStrip menu = new ContextMenuStrip();

            openItem = new ToolStripMenuItem("Open IOPaint");
            openItem.Enabled = false;
            openItem.Click += delegate(object sender, EventArgs e)
            {
                OpenUrl(this.webUrl);
            };

            ToolStripMenuItem stopItem = new ToolStripMenuItem("Stop IOPaint and Exit");
            stopItem.Click += delegate(object sender, EventArgs e)
            {
                StopBackendAndExit();
            };

            menu.Items.Add(openItem);
            menu.Items.Add(stopItem);

            NotifyIcon trayIcon = new NotifyIcon();
            trayIcon.Text = "IOPaint (starting...)";
            trayIcon.Icon = LoadTrayIcon();
            trayIcon.ContextMenuStrip = menu;
            trayIcon.Visible = true;
            trayIcon.DoubleClick += delegate(object sender, EventArgs e)
            {
                OpenUrl(this.webUrl);
            };

            return trayIcon;
        }

        private Icon LoadTrayIcon()
        {
            try
            {
                Icon icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
                if (icon != null)
                {
                    return icon;
                }
            }
            catch
            {
            }

            return SystemIcons.Application;
        }

        private void OnMonitorTimerTick(object sender, EventArgs e)
        {
            if (this.backendPid <= 0)
            {
                return;
            }

            try
            {
                Process process = Process.GetProcessById(this.backendPid);
                if (process.HasExited)
                {
                    ExitThread();
                }
            }
            catch
            {
                ExitThread();
            }
        }

        private void StopBackendAndExit()
        {
            string output;
            string error;
            if (!RunHiddenPowerShell(this.shellPath, BuildPowerShellArguments(this.stopScriptPath, new string[0]), this.root, out output, out error))
            {
                MessageBox.Show(
                    BuildFailureMessage("Failed to stop IOPaint.", output, error),
                    "IOPaint Launcher",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            ExitThread();
        }

        private void PostToUi(MethodInvoker action)
        {
            if (this.uiInvoker.IsDisposed)
            {
                return;
            }

            this.uiInvoker.BeginInvoke(action);
        }

        protected override void ExitThreadCore()
        {
            if (this.monitorTimer != null)
            {
                this.monitorTimer.Stop();
                this.monitorTimer.Dispose();
            }

            if (this.notifyIcon != null)
            {
                this.notifyIcon.Visible = false;
                this.notifyIcon.Dispose();
            }

            if (this.uiInvoker != null)
            {
                this.uiInvoker.Dispose();
            }

            base.ExitThreadCore();
        }
    }

    private static string BuildStartArguments(string scriptPath, string[] launchArgs)
    {
        List<string> args = new List<string>();
        args.Add("-Background");

        for (int index = 0; index < launchArgs.Length; index++)
        {
            args.Add(launchArgs[index]);
        }

        return BuildPowerShellArguments(scriptPath, args.ToArray());
    }

    private static string BuildPowerShellArguments(string scriptPath, string[] scriptArguments)
    {
        StringBuilder builder = new StringBuilder();
        builder.Append("-NoLogo -NoProfile -ExecutionPolicy Bypass -File ");
        builder.Append(Quote(scriptPath));

        for (int index = 0; index < scriptArguments.Length; index++)
        {
            builder.Append(' ');
            builder.Append(Quote(scriptArguments[index]));
        }

        return builder.ToString();
    }

    private static bool RunHiddenPowerShell(string shellPath, string arguments, string workingDirectory, out string standardOutput, out string standardError)
    {
        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = shellPath;
        startInfo.Arguments = arguments;
        startInfo.WorkingDirectory = workingDirectory;
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
        startInfo.RedirectStandardOutput = true;
        startInfo.RedirectStandardError = true;

        using (Process process = Process.Start(startInfo))
        {
            if (process == null)
            {
                standardOutput = string.Empty;
                standardError = "Process.Start returned null.";
                return false;
            }

            standardOutput = process.StandardOutput.ReadToEnd();
            standardError = process.StandardError.ReadToEnd();
            process.WaitForExit();
            return process.ExitCode == 0;
        }
    }

    private static string TryGetNamedValue(string output, string key)
    {
        string[] lines = output.Replace("\r", string.Empty).Split('\n');
        for (int index = 0; index < lines.Length; index++)
        {
            string line = lines[index].Trim();
            if (!line.StartsWith(key + "=", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            return line.Substring(key.Length + 1).Trim();
        }

        return null;
    }

    private static void OpenUrl(string url)
    {
        try
        {
            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = url;
            startInfo.UseShellExecute = true;
            Process.Start(startInfo);
        }
        catch
        {
        }
    }

    private static string BuildFailureMessage(string prefix, string standardOutput, string standardError)
    {
        StringBuilder builder = new StringBuilder();
        builder.Append(prefix);

        if (!string.IsNullOrWhiteSpace(standardOutput))
        {
            builder.AppendLine();
            builder.AppendLine();
            builder.AppendLine("Output:");
            builder.Append(standardOutput.Trim());
        }

        if (!string.IsNullOrWhiteSpace(standardError))
        {
            builder.AppendLine();
            builder.AppendLine();
            builder.AppendLine("Error:");
            builder.Append(standardError.Trim());
        }

        return builder.ToString();
    }

    private static string Quote(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return "\"\"";
        }

        bool requiresQuotes = value.IndexOfAny(new[] { ' ', '\t', '"' }) >= 0;
        if (!requiresQuotes)
        {
            return value;
        }

        StringBuilder builder = new StringBuilder();
        builder.Append('"');
        int backslashCount = 0;

        foreach (char current in value)
        {
            if (current == '\\')
            {
                backslashCount++;
                continue;
            }

            if (current == '"')
            {
                builder.Append('\\', backslashCount * 2 + 1);
                builder.Append(current);
                backslashCount = 0;
                continue;
            }

            if (backslashCount > 0)
            {
                builder.Append('\\', backslashCount);
                backslashCount = 0;
            }

            builder.Append(current);
        }

        if (backslashCount > 0)
        {
            builder.Append('\\', backslashCount * 2);
        }

        builder.Append('"');
        return builder.ToString();
    }

    private static string FindExecutable(string fileName)
    {
        string pathValue = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        string[] pathEntries = pathValue.Split(Path.PathSeparator);

        for (int index = 0; index < pathEntries.Length; index++)
        {
            string entry = pathEntries[index];
            if (string.IsNullOrWhiteSpace(entry))
            {
                continue;
            }

            string candidate = Path.Combine(entry.Trim(), fileName);
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        if (string.Equals(fileName, "powershell.exe", StringComparison.OrdinalIgnoreCase))
        {
            string fallback = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.System),
                "WindowsPowerShell",
                "v1.0",
                "powershell.exe");
            if (File.Exists(fallback))
            {
                return fallback;
            }
        }

        if (string.Equals(fileName, "pwsh.exe", StringComparison.OrdinalIgnoreCase))
        {
            string fallback = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                "PowerShell",
                "7",
                "pwsh.exe");
            if (File.Exists(fallback))
            {
                return fallback;
            }
        }

        return null;
    }

    private static int Fail(string message, int exitCode)
    {
        MessageBox.Show(message, "IOPaint Launcher", MessageBoxButtons.OK, MessageBoxIcon.Error);
        return exitCode;
    }
}
