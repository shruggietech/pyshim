using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Pyshim.Setup;

/// <summary>
///  Simple WinForms surface that guides the user through installing pyshim with admin rights.
///  Everything is wired by hand so we can keep the source ASCII and avoid designer files.
/// </summary>
public sealed class MainForm : Form
{
    private readonly CheckBox _pathCheckBox;
    private readonly CheckBox _currentUserProfileCheckBox;
    private readonly CheckBox _allUsersProfileCheckBox;
    private readonly CheckBox _condaCheckBox;
    private readonly TextBox _logTextBox;
    private readonly Button _installButton;
    private readonly Button _closeButton;
    private readonly Label _statusLabel;
    private readonly string _shimRoot = @"C:\bin\shims";
    private readonly string _pwshPath;

    public MainForm()
    {
        Text = "pyshim Installer";
        StartPosition = FormStartPosition.CenterScreen;
        Width = 640;
        Height = 520;
        MinimizeBox = false;
        MaximizeBox = false;
        FormBorderStyle = FormBorderStyle.FixedDialog;

        _pwshPath = ResolvePwshPath();

        var introLabel = new Label
        {
            Text = "Select the actions you want the installer to perform and click Install.",
            AutoSize = true,
            Left = 12,
            Top = 12
        };

        _pathCheckBox = new CheckBox
        {
            Text = "Ensure C\\bin\\shims is the first PATH entry (user + machine)",
            Left = 12,
            Top = introLabel.Bottom + 12,
            Width = 600,
            Checked = true
        };

        _currentUserProfileCheckBox = new CheckBox
        {
            Text = "Add pyshim auto-import to CurrentUser PowerShell profiles",
            Left = 12,
            Top = _pathCheckBox.Bottom + 8,
            Width = 600,
            Checked = true
        };

        _allUsersProfileCheckBox = new CheckBox
        {
            Text = "Add pyshim auto-import to AllUsers PowerShell profiles",
            Left = 32,
            Top = _currentUserProfileCheckBox.Bottom + 4,
            Width = 580,
            Checked = true
        };

        _condaCheckBox = new CheckBox
        {
            Text = "Refresh shared Conda environments (py310..py314)",
            Left = 12,
            Top = _allUsersProfileCheckBox.Bottom + 8,
            Width = 600,
            Checked = true
        };

        _logTextBox = new TextBox
        {
            Multiline = true,
            ScrollBars = ScrollBars.Vertical,
            Left = 12,
            Top = _condaCheckBox.Bottom + 12,
            Width = 600,
            Height = 300,
            ReadOnly = true
        };

        _statusLabel = new Label
        {
            Text = "Status: Idle",
            AutoSize = true,
            Left = 12,
            Top = _logTextBox.Bottom + 12
        };

        _installButton = new Button
        {
            Text = "Install",
            Width = 90,
            Left = Width - 220,
            Top = _statusLabel.Bottom + 8
        };
        _installButton.Click += OnInstallClicked;

        _closeButton = new Button
        {
            Text = "Close",
            Width = 90,
            Left = _installButton.Right + 10,
            Top = _installButton.Top
        };
        _closeButton.Click += (_, _) => Close();

        Controls.AddRange(new Control[]
        {
            introLabel,
            _pathCheckBox,
            _currentUserProfileCheckBox,
            _allUsersProfileCheckBox,
            _condaCheckBox,
            _logTextBox,
            _statusLabel,
            _installButton,
            _closeButton
        });
    }

    /// <summary>
    ///  Captures the current checkbox selections and kicks off the background install task.
    /// </summary>
    private void OnInstallClicked(object? sender, EventArgs e)
    {
        var options = new InstallerOptions(
            EnsurePath: _pathCheckBox.Checked,
            AddCurrentUserProfiles: _currentUserProfileCheckBox.Checked,
            AddAllUserProfiles: _allUsersProfileCheckBox.Checked,
            RefreshConda: _condaCheckBox.Checked);

        ToggleUiDuringInstall(isInstalling: true);
        Task.Run(() => PerformInstallAsync(options));
    }

    /// <summary>
    ///  Executes the selected install steps sequentially while sending status updates to the UI.
    /// </summary>
    private async Task PerformInstallAsync(InstallerOptions options)
    {
        try
        {
            UpdateStatus("Copying shims...");
            ExtractShims();
            WriteLog("Shims copied to " + _shimRoot + ".");

            if (options.EnsurePath)
            {
                UpdateStatus("Updating PATH...");
                UpdatePathEntries();
                WriteLog("PATH entries updated.");
            }

            if (options.RequirePwshProfileWork)
            {
                UpdateStatus("Wiring PowerShell profiles...");
                ConfigureProfiles(options);
            }

            if (options.RefreshConda)
            {
                UpdateStatus("Refreshing Conda environments (this can take a bit)...");
                RunPwshCommand(
                    script: @$"Import-Module '{_shimRoot.Replace("'", "''")}\pyshim.psm1' -DisableNameChecking -ErrorAction Stop
Refresh-CondaPythons -IgnoreMissing",
                    friendlyName: "Refresh-CondaPythons");
            }

            UpdateStatus("Install complete");
            WriteLog("pyshim installation completed successfully.");
        }
        catch (Exception ex)
        {
            WriteLog("ERROR: " + ex.Message);
            MessageBox.Show(this, ex.Message, "pyshim installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            await Task.Delay(250);
            ToggleUiDuringInstall(isInstalling: false);
        }
    }

    /// <summary>
    ///  Writes the embedded ZIP payload to a temp file and expands it into the shim directory.
    /// </summary>
    private void ExtractShims()
    {
        Directory.CreateDirectory(_shimRoot);
        var tempZip = Path.Combine(Path.GetTempPath(), "pyshim_shims_" + Guid.NewGuid().ToString("N") + ".zip");
        try
        {
            var bytes = Convert.FromBase64String(EmbeddedPayload.Base64Archive);
            File.WriteAllBytes(tempZip, bytes);
            ZipFile.ExtractToDirectory(tempZip, _shimRoot, overwriteFiles: true);
        }
        finally
        {
            if (File.Exists(tempZip))
            {
                File.Delete(tempZip);
            }
        }
    }

    /// <summary>
    ///  Promotes C:\bin\shims to the head of machine, user, and process PATH values.
    /// </summary>
    private void UpdatePathEntries()
    {
        PromotePath(EnvironmentVariableTarget.Machine);
        PromotePath(EnvironmentVariableTarget.User);

        var processPath = Environment.GetEnvironmentVariable("Path") ?? string.Empty;
        var updatedProcessPath = PromotePathValue(processPath, _shimRoot);
        Environment.SetEnvironmentVariable("Path", updatedProcessPath);
    }

    /// <summary>
    ///  Promotes the shim directory inside the requested environment scope, swallowing benign errors.
    /// </summary>
    private void PromotePath(EnvironmentVariableTarget target)
    {
        try
        {
            var current = Environment.GetEnvironmentVariable("Path", target) ?? string.Empty;
            var updated = PromotePathValue(current, _shimRoot);
            Environment.SetEnvironmentVariable("Path", updated, target);
        }
        catch (Exception ex)
        {
            WriteLog($"Warning: unable to update {target} PATH: {ex.Message}");
        }
    }

    /// <summary>
    ///  Removes existing references to the shim directory and re-inserts it at the beginning.
    /// </summary>
    private static string PromotePathValue(string currentValue, string target)
    {
        var normalizedTarget = NormalizePath(target);
        var entries = currentValue.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries)
            .Select(NormalizePath)
            .Where(e => !string.Equals(e, normalizedTarget, StringComparison.OrdinalIgnoreCase))
            .ToList();
        entries.Insert(0, normalizedTarget);
        return string.Join(";", entries);
    }

    /// <summary>
    ///  Runs Enable-PyshimProfile with the scope list that matches the user's selections.
    /// </summary>
    private void ConfigureProfiles(InstallerOptions options)
    {
        var scopes = new System.Collections.Generic.List<string>();
        if (options.AddAllUserProfiles)
        {
            scopes.Add("'AllUsersAllHosts'");
            scopes.Add("'AllUsersCurrentHost'");
        }

        if (options.AddCurrentUserProfiles)
        {
            scopes.Add("'CurrentUserAllHosts'");
            scopes.Add("'CurrentUserCurrentHost'");
        }

        var scopeLiteral = string.Join(",", scopes.Distinct());
        var scriptBuilder = new StringBuilder();
        scriptBuilder.AppendLine($"Import-Module '{_shimRoot.Replace("'", "''")}\\pyshim.psm1' -DisableNameChecking -ErrorAction Stop");
        scriptBuilder.AppendLine($"Enable-PyshimProfile -Scope @({scopeLiteral}) -IncludeWindowsPowerShell:$true -NoBackup -Confirm:$false");

        RunPwshCommand(scriptBuilder.ToString(), "Enable-PyshimProfile");
    }

    /// <summary>
    ///  Launches pwsh.exe, feeds it the provided script via stdin, and surfaces the output in the log view.
    /// </summary>
    private void RunPwshCommand(string script, string friendlyName)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = _pwshPath,
            Arguments = "-NoLogo -NoProfile -Command -",
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to launch pwsh.exe");
        process.StandardInput.WriteLine(script);
        process.StandardInput.WriteLine("exit $LASTEXITCODE");
        process.StandardInput.Flush();
        process.StandardInput.Close();

        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (!string.IsNullOrWhiteSpace(output))
        {
            WriteLog(output.Trim());
        }
        if (!string.IsNullOrWhiteSpace(error))
        {
            WriteLog(error.Trim());
        }

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"{friendlyName} failed with exit code {process.ExitCode}.");
        }
    }

    /// <summary>
    ///  Normalizes a path for case-insensitive comparisons.
    /// </summary>
    private static string NormalizePath(string path)
    {
        return path.Trim().TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
    }

    /// <summary>
    ///  Locates pwsh.exe by probing the standard install directories before falling back to PATH.
    /// </summary>
    private string ResolvePwshPath()
    {
        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "PowerShell", "7", "pwsh.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "PowerShell", "7", "pwsh.exe")
        };

        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        if (CommandExistsOnPath("pwsh.exe"))
        {
            return "pwsh.exe";
        }

        throw new InvalidOperationException("PowerShell 7 (pwsh.exe) was not found. Install it before running this installer.");
    }

    /// <summary>
    ///  Performs a simple PATH scan looking for the requested executable.
    /// </summary>
    private static bool CommandExistsOnPath(string executable)
    {
        var path = Environment.GetEnvironmentVariable("Path") ?? string.Empty;
        var searchPaths = path.Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var searchPath in searchPaths)
        {
            var candidate = Path.Combine(searchPath.Trim(), executable);
            if (File.Exists(candidate))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    ///  Enables or disables the UI controls while an install is running.
    /// </summary>
    private void ToggleUiDuringInstall(bool isInstalling)
    {
        void Toggle()
        {
            _installButton.Enabled = !isInstalling;
            _closeButton.Enabled = !isInstalling;
            _pathCheckBox.Enabled = !isInstalling;
            _currentUserProfileCheckBox.Enabled = !isInstalling;
            _allUsersProfileCheckBox.Enabled = !isInstalling;
            _condaCheckBox.Enabled = !isInstalling;
        }

        if (InvokeRequired)
        {
            Invoke((Action)Toggle);
        }
        else
        {
            Toggle();
        }
    }

    /// <summary>
    ///  Updates the status label while respecting cross-thread calls.
    /// </summary>
    private void UpdateStatus(string message)
    {
        void Update()
        {
            _statusLabel.Text = "Status: " + message;
        }

        if (InvokeRequired)
        {
            Invoke((Action)Update);
        }
        else
        {
            Update();
        }
    }

    /// <summary>
    ///  Appends timestamped log lines to the on-screen log.
    /// </summary>
    private void WriteLog(string message)
    {
        void Append()
        {
            _logTextBox.AppendText("[" + DateTime.Now.ToString("HH:mm:ss") + "] " + message + Environment.NewLine);
        }

        if (InvokeRequired)
        {
            Invoke((Action)Append);
        }
        else
        {
            Append();
        }
    }
}
