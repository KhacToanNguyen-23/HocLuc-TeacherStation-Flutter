using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

internal static class Program {
    [STAThread]
    private static void Main(string[] args) {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        bool created;
        string name = args.Length > 0 && args[0] == "--smoke-test" ? "Local\\HocLucTeacher-Test-" + Process.GetCurrentProcess().Id : "Local\\HocLucTeacher-App";
        using (Mutex mutex = new Mutex(true, name, out created)) {
            if (!created) {
                MessageBox.Show("HocLuc Teacher đang mở. Chọn cửa sổ app trên thanh taskbar.", "HocLuc Teacher", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }
            try { Application.Run(new TeacherWindow(args)); }
            catch (Exception error) { MessageBox.Show("Không mở được HocLuc Teacher: " + error.Message, "HocLuc Teacher", MessageBoxButtons.OK, MessageBoxIcon.Error); Environment.ExitCode = 1; }
            finally { mutex.ReleaseMutex(); }
        }
    }
}

internal sealed class TeacherWindow : Form {
    private readonly string home = AppDomain.CurrentDomain.BaseDirectory;
    private readonly string userRoot;
    private readonly string smokeFolder;
    private readonly bool holdForParentTest;
    private readonly object logLock = new object();
    private readonly TaskCompletionSource<int> readyPort = new TaskCompletionSource<int>();
    private readonly TaskCompletionSource<bool> readyUi = new TaskCompletionSource<bool>();
    private readonly Label loading;
    private WebView2 web;
    private Process service;
    private string serviceUrl;
    private bool closing;
    private bool runtimeFailed;
    private int blockedExternalRequests;

    internal TeacherWindow(string[] args) {
        smokeFolder = args.Length >= 2 && args[0] == "--smoke-test" ? Path.GetFullPath(args[1]) : null;
        holdForParentTest = args.Length >= 3 && args[2] == "--hold-for-parent-exit-test";
        userRoot = smokeFolder == null
            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "HocLuc-Teacher")
            : Path.Combine(smokeFolder, "user-data");
        Directory.CreateDirectory(Path.Combine(userRoot, "data"));
        Directory.CreateDirectory(Path.Combine(userRoot, "logs"));
        if (smokeFolder != null) Directory.CreateDirectory(smokeFolder);
        Text = "HocLuc Teacher";
        Size = new Size(1440, 900);
        MinimumSize = new Size(780, 700);
        StartPosition = FormStartPosition.CenterScreen;
        BackColor = Color.FromArgb(245, 245, 237);
        try { Icon = Icon.ExtractAssociatedIcon(Path.Combine(home, "HocLuc-Teacher.exe")); } catch { }
        loading = new Label { Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleCenter,
            Font = new Font("Segoe UI", 18), ForeColor = Color.FromArgb(23, 62, 53), Text = "Đang mở HocLuc Teacher…" };
        Controls.Add(loading);
        Shown += async delegate { await OpenAsync(); };
        FormClosing += delegate { closing = true; };
        FormClosed += delegate { StopService(); };
    }

    private void Log(string value) {
        lock (logLock) {
            try { File.AppendAllText(Path.Combine(userRoot, "logs", "desktop.log"), DateTime.Now.ToString("s") + " " + value + Environment.NewLine); }
            catch { }
        }
    }
    private async Task OpenAsync() {
        try {
            string java = Path.Combine(home, "runtime", "bin", "java.exe");
            string jar = Path.Combine(home, "resources", "service", "companion-service.jar");
            string browser = Path.Combine(home, "webview2-runtime");
            if (!File.Exists(java) || !File.Exists(jar) || !File.Exists(Path.Combine(browser, "msedgewebview2.exe"))) {
                throw new FileNotFoundException("Thiếu file của app. Hãy giữ toàn bộ thư mục app sau khi giải nén.");
            }
            ProcessStartInfo start = new ProcessStartInfo(java);
            start.Arguments = "-jar " + Quote(jar) + " " + Quote(Path.Combine(home, "resources")) + " 0 " + Quote(Path.Combine(userRoot, "data"));
            start.WorkingDirectory = home;
            start.UseShellExecute = false; start.CreateNoWindow = true;
            start.RedirectStandardOutput = true; start.RedirectStandardError = true;
            start.EnvironmentVariables["HOC_LUC_PARENT_PID"] = Process.GetCurrentProcess().Id.ToString();
            service = new Process { StartInfo = start, EnableRaisingEvents = true };
            service.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e) {
                if (e.Data == null) return;
                Log(e.Data);
                const string prefix = "Teaching Companion: http://127.0.0.1:";
                int port;
                if (e.Data.StartsWith(prefix) && int.TryParse(e.Data.Substring(prefix.Length), out port)) readyPort.TrySetResult(port);
            };
            service.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e) { if (e.Data != null) Log(e.Data); };
            service.Exited += delegate {
                readyPort.TrySetException(new IOException("Java service đã dừng."));
                if (!closing && IsHandleCreated) BeginInvoke((Action)delegate {
                    if (!closing) { runtimeFailed = true; loading.Text = "Dịch vụ của app đã dừng. Đóng và mở lại app."; loading.BringToFront(); }
                });
            };
            service.Start(); service.BeginOutputReadLine(); service.BeginErrorReadLine();
            if (await Task.WhenAny(readyPort.Task, Task.Delay(15000)) != readyPort.Task) throw new TimeoutException("Dịch vụ chưa sẵn sàng.");
            int actualPort = await readyPort.Task;
            serviceUrl = "http://127.0.0.1:" + actualPort;
            Log("Desktop PID=" + Process.GetCurrentProcess().Id + "; service PID=" + service.Id + "; URL=" + serviceUrl);
            WriteSession(actualPort);
            CoreWebView2Environment environment = await CoreWebView2Environment.CreateAsync(browser, Path.Combine(userRoot, "webview"));
            if (closing) return;
            web = new WebView2 { Dock = DockStyle.Fill };
            Controls.Add(web);
            loading.BringToFront();
            await web.EnsureCoreWebView2Async(environment);
            if (closing) return;
            web.CoreWebView2.Settings.AreDevToolsEnabled = smokeFolder != null;
            web.CoreWebView2.Settings.AreDefaultContextMenusEnabled = false;
            web.CoreWebView2.Settings.IsStatusBarEnabled = false;
            web.CoreWebView2.PermissionRequested += delegate(object sender, CoreWebView2PermissionRequestedEventArgs e) { e.State = CoreWebView2PermissionState.Deny; };
            web.CoreWebView2.NavigationStarting += delegate(object sender, CoreWebView2NavigationStartingEventArgs e) {
                Uri uri;
                if (!Uri.TryCreate(e.Uri, UriKind.Absolute, out uri) || uri.GetLeftPart(UriPartial.Authority) != serviceUrl) e.Cancel = true;
            };
            web.CoreWebView2.NewWindowRequested += delegate(object sender, CoreWebView2NewWindowRequestedEventArgs e) { e.Handled = true; };
            web.CoreWebView2.WebMessageReceived += delegate(object sender, CoreWebView2WebMessageReceivedEventArgs e) {
                if (e.Source != serviceUrl + "/") return;
                if (e.WebMessageAsJson.Contains("flutter-ready")) readyUi.TrySetResult(true);
            };
            web.CoreWebView2.ProcessFailed += delegate { Log("WebView2 process failed"); runtimeFailed = true; };
            // Flutter's renderer/fonts are bundled locally. Flat's SDK retains
            // network access for its teacher-provided Netless session.
            if (smokeFolder != null) {
                web.CoreWebView2.AddWebResourceRequestedFilter("*", CoreWebView2WebResourceContext.All);
                web.CoreWebView2.WebResourceRequested += delegate(object sender, CoreWebView2WebResourceRequestedEventArgs e) {
                    Uri resource;
                    if (Uri.TryCreate(e.Request.Uri, UriKind.Absolute, out resource)
                        && (resource.Scheme == "http" || resource.Scheme == "https")
                        && resource.GetLeftPart(UriPartial.Authority) != serviceUrl) {
                        blockedExternalRequests++;
                        e.Response = environment.CreateWebResourceResponse(new MemoryStream(), 403, "Offline smoke test", "Content-Type: text/plain");
                    }
                };
            }
            web.CoreWebView2.Navigate(serviceUrl + "/");
            if (await Task.WhenAny(readyUi.Task, Task.Delay(45000)) != readyUi.Task) throw new TimeoutException("Giao diện chưa tải xong. Xem desktop.log để kiểm tra.");
            await readyUi.Task;
            loading.Visible = false; web.BringToFront();
            Log("Flutter UI ready");
            if (smokeFolder != null) await SmokeAsync();
        } catch (Exception error) {
            if (closing) return;
            runtimeFailed = true; Log(error.ToString());
            if (smokeFolder != null) {
                File.WriteAllText(Path.Combine(smokeFolder, "failure.txt"), error.ToString()); Environment.ExitCode = 1; Close();
            } else {
                MessageBox.Show("Không mở được app: " + error.Message + "\n\nLog: " + Path.Combine(userRoot, "logs", "desktop.log"), "HocLuc Teacher", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Close();
            }
        }
    }

    private void WriteSession(int port) {
        var session = new Dictionary<string, object>();
        session["hostPid"] = Process.GetCurrentProcess().Id; session["servicePid"] = service.Id;
        session["port"] = port; session["url"] = serviceUrl; session["dataDirectory"] = Path.Combine(userRoot, "data");
        File.WriteAllText(Path.Combine(userRoot, "session.json"), new JavaScriptSerializer().Serialize(session));
    }
    private async Task SmokeAsync() {
        var serializer = new JavaScriptSerializer();
        string token;
        using (WebClient client = new WebClient()) {
            var bootstrap = serializer.Deserialize<Dictionary<string, object>>(client.DownloadString(serviceUrl + "/api/bootstrap"));
            token = (string)bootstrap["token"];
            client.Headers["X-Companion-Token"] = token;
            string capabilities = client.DownloadString(serviceUrl + "/api/capabilities");
            client.Headers["Content-Type"] = "application/json; charset=utf-8";
            client.Encoding = System.Text.Encoding.UTF8;
            string expected = "{\"title\":\"Bài giảng đóng gói\",\"notes\":\"smoke-test\",\"pages\":[[],[],[]]}";
            client.UploadString(serviceUrl + "/api/lesson", "PUT", expected);
            string actual = client.DownloadString(serviceUrl + "/api/lesson");
            if (!actual.Contains("Bài giảng đóng gói")) throw new IOException("Packaged save/read failed");
            File.WriteAllText(Path.Combine(smokeFolder, "capabilities.json"), capabilities);
        }
        using (FileStream image = File.Create(Path.Combine(smokeFolder, "desktop-preview.png"))) {
            await web.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png, image);
        }
        if (runtimeFailed) throw new IOException("Runtime failed during smoke test");
        File.WriteAllText(Path.Combine(smokeFolder, "passed.json"), serializer.Serialize(new Dictionary<string, object> {
            { "ready", true }, { "hostPid", Process.GetCurrentProcess().Id }, { "servicePid", service.Id },
            { "port", new Uri(serviceUrl).Port }, { "saveRead", true }, { "bundledJava", true },
            { "bundledWebView2", true }, { "flutterRendered", true }, { "externalResourcesDenied", true }, { "blockedExternalRequests", blockedExternalRequests }
        }));
        Environment.ExitCode = 0;
        if (!holdForParentTest) Close();
    }
    private void StopService() {
        if (web != null) { web.Dispose(); web = null; }
        if (service != null) {
            try { if (!service.HasExited) { service.Kill(); service.WaitForExit(5000); } } catch { }
            service.Dispose(); service = null;
        }
        try { File.Delete(Path.Combine(userRoot, "session.json")); } catch { }
    }
    private static string Quote(string value) { return "\"" + value + "\""; }
}
