using System;
using System.Windows.Forms;

namespace Pyshim.Setup;

internal static class Program
{
    /// <summary>
    ///  Entry point for the pyshim installer UI. STA is required for WinForms.
    /// </summary>
    [STAThread]
    private static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}
