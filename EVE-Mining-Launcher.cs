using System;
using System.IO;
using System.Threading;
using System.Windows.Forms;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Runtime.InteropServices;
using System.Reflection;

[assembly: AssemblyTitle("EVE Mining")]
[assembly: AssemblyProduct("EVE Mining")]
[assembly: AssemblyCompany("Marcel Ijonen [NO.W8]")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

internal static class MiningLauncher
{
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern int SetCurrentProcessExplicitAppUserModelID(string appID);

    [STAThread]
    private static int Main(string[] args)
    {
        Application.EnableVisualStyles();
        SetCurrentProcessExplicitAppUserModelID("EVE.Mining.Monitor");
        bool check = args.Length > 0 && args[0] == "--check";
        bool created;
        using (Mutex mutex = new Mutex(true, "Local\\EVE-Mining-Monitor" + (check ? "-check" : ""), out created))
        {
            if (!created) { MessageBox.Show("EVE Mining is already running.", "EVE Mining"); return 0; }
            try
            {
                string root = AppDomain.CurrentDomain.BaseDirectory;
                string data = check && args.Length > 1 ? Path.GetFullPath(args[1]) : root;
                string script = Path.Combine(root, "EVE-Ice-Monitor.ps1");
                using (Runspace runspace = RunspaceFactory.CreateRunspace())
                {
                    runspace.ApartmentState = ApartmentState.STA;
                    runspace.ThreadOptions = PSThreadOptions.UseCurrentThread;
                    runspace.Open();
                    using (PowerShell ps = PowerShell.Create())
                    {
                        ps.Runspace = runspace;
                        ps.AddCommand("Set-ExecutionPolicy").AddParameter("Scope", "Process").AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force");
                        ps.Invoke();
                        if (ps.HadErrors) throw new InvalidOperationException(ps.Streams.Error[0].ToString());
                        ps.Commands.Clear();
                        ps.AddCommand(script).AddParameter("DataDirectory", data);
                        if (check) ps.AddParameter("NoRun");
                        ps.Invoke();
                        if (ps.HadErrors) throw new InvalidOperationException(ps.Streams.Error[0].ToString());
                        if (check) File.WriteAllText(Path.Combine(data, "launcher-check.txt"), "Embedded Windows PowerShell and UI initialization OK.");
                    }
                }
                return 0;
            }
            catch (Exception ex)
            {
                if (check && args.Length > 1) { Directory.CreateDirectory(args[1]); File.WriteAllText(Path.Combine(args[1], "launcher-error.txt"), ex.ToString()); }
                else MessageBox.Show(ex.Message, "EVE Mining - startup error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
            finally { mutex.ReleaseMutex(); }
        }
    }
}
