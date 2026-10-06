// 阶段日志 Mac App：一个原生窗口（WKWebView），在后台启动本地服务 server.py。
// 数据仍然是 App 所在文件夹里的 data.json。编译方法见 build.sh。
import Cocoa
import WebKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
    let env = ProcessInfo.processInfo.environment
    lazy var port = Int(env["PHASELOG_PORT"] ?? "") ?? 8790
    lazy var home = URL(string: "http://127.0.0.1:\(port)/")!
    var window: NSWindow!
    var web: WKWebView!
    var root: URL?
    var server: Process?          // 只有自己启动的服务才在退出时关掉
    var starts = 0, attempts = 0
    var tested = false

    // MARK: 启动

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        buildWindow()
        guard let r = findRoot() else {
            fatal("找不到“阶段日志”文件夹（里面应有 server.py 和 index.html）。\n请把这个 App 放回那个文件夹里再打开。", quit: true)
            return
        }
        root = r
        load()
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    // App 旁边的文件夹 → 上次用过的文件夹 → 桌面上的“阶段日志”
    func findRoot() -> URL? {
        let fm = FileManager.default
        var dirs = [Bundle.main.bundleURL.deletingLastPathComponent()]
        if let saved = UserDefaults.standard.string(forKey: "root") { dirs.append(URL(fileURLWithPath: saved)) }
        dirs.append(fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/阶段日志"))
        for d in dirs where fm.fileExists(atPath: d.appendingPathComponent("server.py").path)
                         && fm.fileExists(atPath: d.appendingPathComponent("index.html").path) {
            UserDefaults.standard.set(d.path, forKey: "root")
            return d
        }
        return nil
    }

    func buildWindow() {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "app")
        web = WKWebView(frame: .zero, configuration: cfg)
        web.uiDelegate = self
        web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = true
        let z = UserDefaults.standard.double(forKey: "zoom")
        if z > 0 { web.pageZoom = z }

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 840),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "阶段日志"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // 标题栏颜色和网页顶栏一致
        window.backgroundColor = NSColor(name: nil) { a in
            a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.066, green: 0.066, blue: 0.07, alpha: 1)
                : NSColor(srgbRed: 0.965, green: 0.965, blue: 0.976, alpha: 1)
        }
        window.minSize = NSSize(width: 760, height: 560)
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)
        // 测试用：让窗口也能出现在全屏 App 所在的空间
        if env["PHASELOG_ALL_SPACES"] != nil { window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] }
        window.isReleasedWhenClosed = false
        window.contentView = web
        if !window.setFrameUsingName("main") { window.center() }
        window.setFrameAutosaveName("main")
        window.makeKeyAndOrderFront(nil)
    }

    func load() {
        web.load(URLRequest(url: home, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5))
    }

    // MARK: 本地服务

    func ensureServer() {
        if server?.isRunning == true || starts >= 3 { return }
        guard let root = root else { return }
        let pythons = ["/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
                       "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3",
                       "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
        guard let py = pythons.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            fatal("没有找到 Python 3。")
            return
        }
        starts += 1
        let p = Process()
        p.executableURL = URL(fileURLWithPath: py)
        p.arguments = [root.appendingPathComponent("server.py").path]
        p.currentDirectoryURL = root
        var e = env
        e["NO_BROWSER"] = "1"
        e["PORT"] = String(port)
        e["PYTHONUNBUFFERED"] = "1"
        if let d = env["PHASELOG_DATA"] { e["DATA_FILE"] = d }
        p.environment = e
        let log = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/阶段日志.log")
        if !FileManager.default.fileExists(atPath: log.path) { FileManager.default.createFile(atPath: log.path, contents: nil) }
        if let h = try? FileHandle(forWritingTo: log) {
            h.seekToEndOfFile()
            p.standardOutput = h
            p.standardError = h
        }
        do { try p.run(); server = p } catch { fatal("启动本地服务失败：\(error.localizedDescription)") }
    }

    // 页面保存失败时会发来 "restart-server"
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.body as? String) == "restart-server" { starts = 0; ensureServer() }
    }

    // 服务还没开：启动它，再每 0.25 秒重试，最多约 10 秒
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let e = error as NSError
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        ensureServer()
        attempts += 1
        if attempts > 40 {
            attempts = 0
            fatal("本地服务没有启动成功：\(e.localizedDescription)\n可以按 ⌘R 重试。日志在 ~/Library/Logs/阶段日志.log")
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.load() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        attempts = 0
        runSelfTest()
    }

    // MARK: 网页里的 alert / confirm

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = NSAlert()
        a.messageText = message
        a.addButton(withTitle: "好")
        a.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        if env["PHASELOG_AUTOCONFIRM"] != nil { completionHandler(true); return }   // 测试用
        let a = NSAlert()
        a.messageText = message
        a.addButton(withTitle: "确定")
        a.addButton(withTitle: "取消")
        a.beginSheetModal(for: window) { r in completionHandler(r == .alertFirstButtonReturn) }
    }

    // MARK: 退出：先保存，再关掉自己启动的服务

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let web = web else { return .terminateNow }
        var done = false
        let finish = {
            if done { return }
            done = true
            self.server?.terminate()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        web.callAsyncJavaScript("if (typeof loaded !== 'undefined' && loaded) { await flush(); } return true;",
                                arguments: [:], in: nil, in: .page) { _ in finish() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { finish() }
        return .terminateLater
    }

    // MARK: 菜单

    func buildMenu() {
        let main = NSMenu()
        func menu(_ title: String, _ items: [NSMenuItem]) -> NSMenu {
            let m = NSMenu(title: title)
            items.forEach { m.addItem($0) }
            let holder = NSMenuItem()
            holder.submenu = m
            main.addItem(holder)
            return m
        }
        func item(_ title: String, _ action: Selector?, _ key: String = "",
                  _ mods: NSEvent.ModifierFlags = .command, mine: Bool = false) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            if mine { i.target = self }
            return i
        }
        _ = menu("阶段日志", [
            item("关于阶段日志", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""),
            .separator(),
            item("隐藏阶段日志", #selector(NSApplication.hide(_:)), "h"),
            item("隐藏其他", #selector(NSApplication.hideOtherApplications(_:)), "h", [.command, .option]),
            .separator(),
            item("退出阶段日志", #selector(NSApplication.terminate(_:)), "q"),
        ])
        _ = menu("文件", [
            item("新领域…", #selector(newDomain(_:)), "n", mine: true),
            item("关闭窗口", #selector(NSWindow.performClose(_:)), "w"),
        ])
        _ = menu("编辑", [
            item("撤销", Selector(("undo:")), "z"),
            item("重做", Selector(("redo:")), "z", [.command, .shift]),
            .separator(),
            item("剪切", #selector(NSText.cut(_:)), "x"),
            item("拷贝", #selector(NSText.copy(_:)), "c"),
            item("粘贴", #selector(NSText.paste(_:)), "v"),
            item("全选", #selector(NSText.selectAll(_:)), "a"),
        ])
        let zoomInAlt = item("放大", #selector(zoomIn(_:)), "=", mine: true)
        zoomInAlt.isHidden = true
        zoomInAlt.allowsKeyEquivalentWhenHidden = true
        _ = menu("显示", [
            item("总览", #selector(goHome(_:)), "1", mine: true),
            item("日历", #selector(goCalendar(_:)), "2", mine: true),
            .separator(),
            item("放大", #selector(zoomIn(_:)), "+", mine: true),
            zoomInAlt,
            item("缩小", #selector(zoomOut(_:)), "-", mine: true),
            item("实际大小", #selector(zoomReset(_:)), "0", mine: true),
            .separator(),
            item("重新载入", #selector(reload(_:)), "r", mine: true),
            item("进入全屏幕", #selector(NSWindow.toggleFullScreen(_:)), "f", [.command, .control]),
        ])
        let win = menu("窗口", [
            item("最小化", #selector(NSWindow.performMiniaturize(_:)), "m"),
            item("缩放", #selector(NSWindow.performZoom(_:)), ""),
        ])
        NSApp.windowsMenu = win
        NSApp.mainMenu = main
    }

    func js(_ code: String) { web.evaluateJavaScript(code, completionHandler: nil) }
    @objc func newDomain(_ s: Any?) { js("typeof newDomain === 'function' && newDomain()") }
    @objc func goHome(_ s: Any?) { js("location.hash = '#/'") }
    @objc func goCalendar(_ s: Any?) { js("location.hash = '#/cal'") }
    @objc func reload(_ s: Any?) { attempts = 0; web.reloadFromOrigin() }
    @objc func zoomIn(_ s: Any?) { setZoom(web.pageZoom + 0.1) }
    @objc func zoomOut(_ s: Any?) { setZoom(web.pageZoom - 0.1) }
    @objc func zoomReset(_ s: Any?) { setZoom(1) }
    func setZoom(_ z: CGFloat) {
        let v = (min(max(z, 0.6), 2.0) * 10).rounded() / 10
        web.pageZoom = v
        UserDefaults.standard.set(Double(v), forKey: "zoom")
    }

    func fatal(_ msg: String, quit: Bool = false) {
        let a = NSAlert()
        a.messageText = "阶段日志打不开"
        a.informativeText = msg
        a.addButton(withTitle: "好")
        a.runModal()
        if quit { NSApp.terminate(nil) }
    }

    // MARK: 测试用（只有设置了 PHASELOG_TEST_JS / PHASELOG_SNAPSHOT 环境变量才会执行）

    func runSelfTest() {
        guard !tested, env["PHASELOG_TEST_JS"] != nil || env["PHASELOG_SNAPSHOT"] != nil else { return }
        tested = true
        let quit = env["PHASELOG_QUIT"]
        let snapshotThenQuit = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard let path = self.env["PHASELOG_SNAPSHOT"] else {
                    if quit != nil { NSApp.terminate(nil) }
                    return
                }
                self.web.takeSnapshot(with: nil) { img, _ in
                    if let tiff = img?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: URL(fileURLWithPath: path))
                    }
                    print("[test] snapshot \(path)")
                    fflush(stdout)
                    if quit != nil { NSApp.terminate(nil) }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard let code = self.env["PHASELOG_TEST_JS"] else { snapshotThenQuit(); return }
            self.web.callAsyncJavaScript(code, arguments: [:], in: nil, in: .page) { r in
                print("[test] js: \(r)")
                fflush(stdout)
                if quit == "now" { NSApp.terminate(nil) } else { snapshotThenQuit() }
            }
        }
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()   // NSApp.delegate 是弱引用，这个局部变量在 run() 期间一直有效
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
