import Cocoa
import CoreData

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let clicksMenuItem: NSMenuItem = NSMenuItem()
    let pressesMenuItem: NSMenuItem = NSMenuItem()
    let menu: NSMenu = NSMenu()
    
    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(named: NSImage.Name(rawValue: "StatusBarButtonImage"))
        }
        
        setMenuItems()
        setupMenu()
        setupLogging()
    }
    
    func setMenuItems() {
        var clickTotal = 0
        var pressTotal = 0

        if let clicksToday = fetchTodaysTotalIfPresent("mouse") {
            clickTotal = clicksToday
        }
        if let pressesToday = fetchTodaysTotalIfPresent("key") {
            pressTotal = pressesToday
        }
        clicksMenuItem.title = "Clicks today: \(clickTotal)"
        pressesMenuItem.title = "Key presses today: \(pressTotal)"
    }
    
    @objc func resync(_ sender: AnyObject) {
        print("About to resync")
    }
    
    func setupLogging() {
        if acquirePrivileges() {
            print("Accessibility Enabled")
            setupMasks()
        }
        else {
            print("Accessibility Disabled")
        }
    }
    
    func setupMasks() {
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.leftMouseDown, handler: { event in
            print("Left mouse click")
            self.incrementOrCreate("mouse")
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.rightMouseDown, handler: { event in
            print("Right mouse click")
            self.incrementOrCreate("mouse")
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: { event in
            print("Key press char:\(event.characters) key code: \(event.keyCode)")
            guard ![123, 124].contains(event.keyCode) else {
                // Left or right arrow presssed in conjunction with a modifier key
                print("Not counted as a valid key press")
                return
            }
            self.incrementOrCreate("key")
        })
        
        NSEvent.addGlobalMonitorForEvents(matching: NSEvent.EventTypeMask.flagsChanged, handler: { event in
            if event.modifierFlags.rawValue == 256 {
                print("Modifier key up")
                self.incrementOrCreate("key")
            }
        })
    }

    func setupMenu() {
        menu.addItem(clicksMenuItem)
        menu.addItem(pressesMenuItem)
        menu.addItem(NSMenuItem(title: "Resync", action: #selector(AppDelegate.resync(_:)), keyEquivalent: "R"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }
    
    func todaysDateAsString() -> String {
        let todaysDate = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: todaysDate)
    }
    
    func fetchTodaysObjectIfPresent(_ type: String) -> NSManagedObject? {
        let managedContext = self.managedObjectContext
        let dateString = todaysDateAsString()
        
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "DayTotal")
        fetchRequest.predicate = NSPredicate(format: "createdAt = %@ AND type = %@", dateString, type)
        
        // maybe store todays managed object id in variable
        
        do {
            if let results = try managedContext.fetch(fetchRequest) as? [NSManagedObject] {
                if results.count == 1 {
                    return results[0]
                }
            }
        } catch {
            // handle error properly and add to counter and then change icon if too many errors, or post notification
            print("Error")
        }
        return nil
    }
    
    func fetchTodaysTotalIfPresent(_ type: String) -> Int? {
        if let todaysObject = fetchTodaysObjectIfPresent(type) {
            return todaysObject.value(forKey: "total") as? Int
        }
        return nil
    }
    
    func incrementOrCreate(_ type: String) {
        let managedContext = self.managedObjectContext
        let dateString = todaysDateAsString()
        var newTotal: Int
        
        if let todaysObject = fetchTodaysObjectIfPresent(type) {
            let currentTotal = todaysObject.value(forKey: "total") as! Int
            newTotal = currentTotal + 1
            todaysObject.setValue(newTotal, forKey: "total")
        } else {
            let entity =  NSEntityDescription.entity(forEntityName: "DayTotal", in: managedContext)
            let dayTotal = NSManagedObject(entity: entity!, insertInto: managedContext)
            dayTotal.setValue(dateString, forKey: "createdAt")
            dayTotal.setValue(type, forKey: "type")
            newTotal = 1
        }
        
        try! managedContext.save()
        updateMenuTitle(type, value: newTotal)
    }
    
    func updateMenuTitle(_ type: String, value: Int) {
        if type == "key" {
            pressesMenuItem.title = "Key presses today: \(value)"
        } else if type == "mouse" {
            clicksMenuItem.title = "Clicks today: \(value)"
        }
    }
    
    func acquirePrivileges() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        var accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        guard accessibilityEnabled else {
            let alert = NSAlert()
            alert.messageText = "Enable Jottly"
            alert.informativeText = "Once you have enabled Jottly in System Preferences, click OK."
            alert.beginSheetModal(for: self.window, completionHandler: { response in
                if AXIsProcessTrustedWithOptions(options as CFDictionary) {
                    accessibilityEnabled = true
                } else {
                    NSApp.terminate(self)
                }
            })
            return accessibilityEnabled
        }

        return accessibilityEnabled
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "gg.hc.Jottly" in the user's Application Support directory.
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportURL = urls[urls.count - 1]
        return appSupportURL.appendingPathComponent("gg.hc.Jottly")
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "Jottly", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.) This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        let fileManager = FileManager.default
        var failError: NSError? = nil
        var shouldFail = false
        var failureReason = "There was an error creating or loading the application's saved data."

        // Make sure the application files directory is there
        do {
            let properties = try (self.applicationDocumentsDirectory as NSURL).resourceValues(forKeys: [URLResourceKey.isDirectoryKey])
            if !(properties[URLResourceKey.isDirectoryKey]! as AnyObject).boolValue {
                failureReason = "Expected a folder to store application data, found a file \(self.applicationDocumentsDirectory.path)."
                shouldFail = true
            }
        } catch  {
            let nserror = error as NSError
            if nserror.code == NSFileReadNoSuchFileError {
                do {
                    try fileManager.createDirectory(atPath: self.applicationDocumentsDirectory.path, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    failError = nserror
                }
            } else {
                failError = nserror
            }
        }
        
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = nil
        if failError == nil {
            coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
            let url = self.applicationDocumentsDirectory.appendingPathComponent("CocoaAppCD.storedata")
            do {
                try coordinator!.addPersistentStore(ofType: NSXMLStoreType, configurationName: nil, at: url, options: nil)
            } catch {
                failError = error as NSError
            }
        }
        
        if shouldFail || (failError != nil) {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject
            if failError != nil {
                dict[NSUnderlyingErrorKey] = failError
            }
            let error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            NSApplication.shared.presentError(error)
            abort()
        } else {
            return coordinator!
        }
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving and Undo support

    @IBAction func saveAction(_ sender: AnyObject!) {
        // Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing before saving")
        }
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                let nserror = error as NSError
                NSApplication.shared.presentError(nserror)
            }
        }
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        return managedObjectContext.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Save changes in the application's managed object context before the application terminates.
        
        if !managedObjectContext.commitEditing() {
            NSLog("\(NSStringFromClass(type(of: self))) unable to commit editing to terminate")
            return .terminateCancel
        }
        
        if !managedObjectContext.hasChanges {
            return .terminateNow
        }
        
        do {
            try managedObjectContext.save()
        } catch {
            let nserror = error as NSError
            // Customize this code block to include application-specific recovery steps.
            let result = sender.presentError(nserror)
            if result {
                return .terminateCancel
            }
            
            let question = NSLocalizedString("Could not save changes while quitting. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == NSApplication.ModalResponse.alertFirstButtonReturn {
                return .terminateCancel
            }
        }
        // If we got here, it is time to quit.
        return .terminateNow
    }

}

