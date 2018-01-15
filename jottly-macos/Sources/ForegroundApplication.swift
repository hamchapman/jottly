import Cocoa

class StatusMenuController: NSObject {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let BROWSERS = ["Firefox", "Safari", "Google Chrome", "Google Chrome Canary"]
    let BASE_ENDPOINT = "https://proddy.herokuapp.com"
    let defaults = UserDefaults.standard

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var proddableAppList: NSMenuItem!
    @IBOutlet weak var proddableAppListMenu: NSMenu!

    @IBAction func quitClicked(_ sender: AnyObject) {
        NSApplication.shared.terminate(self)
    }

    @IBAction func resetUsername(_ sender: AnyObject) {
        defaults.set(nil, forKey: "user_id")
    }

    override func awakeFromNib() {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(rawValue: "proddy-logo-black32"))
        }

        statusItem.menu = statusMenu

        checkRunningApplication()

        
        Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(StatusMenuController.checkRunningApplication), userInfo: nil, repeats: true)

        //        initialiseExtremeMode()
    }

    @objc func activateExtremeMode(_ item: NSMenuItem) {
        bringAppToForeground(item.title)
    }

    func initialiseExtremeMode() {
        //        let pid = app.processIdentifier
        let windowList: CFArray = CGWindowListCopyWindowInfo(CGWindowListOption(), CGWindowID(0))!
        //        print(windowList)

        for win in windowList {
            if let windy = win as? Dictionary<String, AnyObject> {
                print(windy["kCGWindowOwnerPID"]!)
                print(windy["kCGWindowNumber"]!)
                print(windy["kCGWindowName"]!)

                if let windowName = windy["kCGWindowName"] as? String {
                    if windowName == "room_channel.ex — hcgg" {
                        if let windowNum = windy["kCGWindowNumber"] as? Int {
                            print(windowNum)
                            let special = NSApp.window(withWindowNumber: windowNum)
                            print(special)
                            special!.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
                            //                            special!.level = Int(CGWindowLevelForKey(.FloatingWindowLevelKey))
                        }
                    }
                }
            }
        }
    }

    func bringAppToForeground(_ appName: String) {
        for runningApp in NSWorkspace.shared.runningApplications {
            if let name = runningApp.localizedName, name == appName {
                runningApp.activate(options: NSApplication.ActivationOptions.activateIgnoringOtherApps)
            }
        }
    }

    @objc func checkRunningApplication() {

        let newProddableAppListMenu = NSMenu()

        for runningApp in NSWorkspace.shared.runningApplications {
            if runningApp.activationPolicy == NSApplication.ActivationPolicy.regular {

                let appListItem = NSMenuItem(title: runningApp.localizedName!, action: #selector(StatusMenuController.activateExtremeMode(_:)), keyEquivalent: "")
                appListItem.image = runningApp.icon!
                appListItem.target = self

                // get screenshots of windows

                newProddableAppListMenu.addItem(appListItem)

                if let name = runningApp.localizedName, runningApp.isActive {
                    print("\(runningApp.localizedName!)")

                    var url: String? = nil

                    if BROWSERS.contains(name) {
                        url = getBrowserTabURL(name)
                        print(url)
                    }

                    updateServer(name, url: url)
                }
            }
        }

        statusMenu.setSubmenu(newProddableAppListMenu, for: proddableAppList)
    }

    func updateServer(_ name: String, url: String? = nil) {
        //        guard let _ = defaults.string(forKey: "user_id") else {
        //            createUserWithVivansMagicalBackend()
        //            return
        //        }
        //
        //        var hostname: String? = nil
        //
        //        if url != nil {
        //            if let host = URL(string: url!)!.host {
        //                print("is this optional: \(host)")
        //                hostname = host
        //            } else {
        //                hostname = url!
        //            }
        //        }
        //
        //        var request = URLRequest(url: URL(string: "\(BASE_ENDPOINT)/events")!)
        //        request.httpMethod = "POST"
        //
        //        if let h = hostname {
        //            request.httpBody = "app_name=\(name)&hostname=\(h)&user_id=\(defaults.string(forKey: "user_id")!)&timestamp=\(Date().timeIntervalSince1970)".data(using: String.Encoding.utf8)
        //        } else {
        //            request.httpBody = "app_name=\(name)&user_id=\(defaults.string(forKey: "user_id")!)&timestamp=\(Date().timeIntervalSince1970)".data(using: .utf8)
        //        }
        //
        //        let task = URLSession.shared.dataTask(with: request) { data, response, error in
        //            guard error == nil else {
        //                print("Error: \(error!.localizedDescription)")
        //                return
        //            }
        //
        //            if let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        //                do {
        //                    if let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, AnyObject> {
        //                        print(json)
        //                        if let rank = json["rank"] as? Int, let numUsers = json["no_of_users"] as? Int, let leader = json["leader"] as? String {
        //                            if let button = self.statusItem.button {
        //                                button.image = NSImage(named: "proddy-logo-\(self.getIconColourFromRankAndUsers(rank, numUsers: numUsers))32")
        //                            }
        //                            self.currentLeader.title = "Today's leader: \(leader)"
        //                            self.yourRank.title = "Rank \(rank) out of \(numUsers)"
        //                        }
        //                    }
        //                } catch {
        //                    print("Error getting event_id")
        //                }
        //            } else {
        //                print("Error from Vivan's backend")
        //            }
        //        }
        //
        //        task.resume()
    }

    func createUser() {
        //        let username = NSUserName()
        //
        //        var request = URLRequest(url: URL(string: "\(BASE_ENDPOINT)/users")!)
        //        request.httpMethod = "POST"
        //        request.httpBody = "user_name=\(username)".data(using: .utf8)
        //
        //        let task = URLSession.shared.dataTask(with: request) { data, response, error in
        //            guard error == nil else {
        //                print("Error: \(error!.localizedDescription)")
        //                return
        //            }
        //
        //            if let httpResponse = response as? HTTPURLResponse, (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
        //                do {
        //                    if let json = try JSONSerialization.jsonObject(with: data!, options: []) as? Dictionary<String, AnyObject> {
        //                        print(json)
        //                        if let userId = json["user_id"] as? String {
        //                            print(userId)
        //                            self.defaults.set(userId, forKey: "user_id")
        //                        }
        //                    }
        //                } catch {
        //                    print("Error getting user_id")
        //                }
        //            } else {
        //                print("Error from Vivan's backend")
        //            }
        //        }
        //
        //        task.resume()
    }

    func getBrowserTabURL(_ appName: String) -> String? {
        let script = generateScript(appName)
        var error: NSDictionary?

        if let scriptObject = NSAppleScript(source: script) {
            if let output: NSAppleEventDescriptor = scriptObject.executeAndReturnError(&error) {
                return output.stringValue
            } else if error != nil {
                print("error: \(error!)")
            }
        }
        return nil
    }

    func generateScript(_ appName: String) -> String {
        return "set frontApp to \"\(appName)\"\n" +
            "if (frontApp = \"Safari\") or (frontApp = \"Webkit\") then\n" +
            "using terms from application \"Safari\"\n" +
            "tell application frontApp to set currentTabUrl to URL of front document\n" +
            "end using terms from\n" +
            "else if (frontApp = \"Google Chrome\") or (frontApp = \"Google Chrome Canary\") or (frontApp = \"Chromium\") then\n" +
            "using terms from application \"Google Chrome\"\n" +
            "tell application frontApp to set currentTabUrl to URL of active tab of front window\n " +
            "end using terms from\n" +
            "else\n" +
            "return \"You need a supported browser as your frontmost app\"\n" +
            "end if\n" +
            "return currentTabUrl"
    }

}
