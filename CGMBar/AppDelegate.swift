//
//  AppDelegate.swift
//  CGMBar
//
//  Created by James Woglom on 5/17/21.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    
    var statusBarItem: NSStatusItem!
    var statusBarMenu: NSMenu!
    var settingsMenu: NSMenu!
    
    var updateTimer: Timer!
    var lastUpdateDate: Date!
    
    enum PreferenceField : String {
        case nightscoutUrl
        case statusBarShowDelta
        case statusBarAlwaysShowAge
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        self.statusBarMenu = NSMenu(title: "CGMBar")
        if let menu = self.statusBarMenu {
            menu.addItem(withTitle: "Last updated: unknown", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Update Now", action: #selector(updateBar), keyEquivalent: "u")
            menu.addItem(withTitle: "Settings", action: nil, keyEquivalent: "s")
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            
            settingsMenu = NSMenu(title: "Settings")
            settingsMenu.addItem(withTitle: "Set Nightscout URL", action: #selector(settingsNightscoutUrl), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Show Delta", action: #selector(settingsShowDelta), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Always Show Age", action: #selector(settingsAlwaysShowAge), keyEquivalent: "")
            updateCheckboxSettings()
            
            menu.setSubmenu(settingsMenu, for: menu.item(withTitle: "Settings")!)
            menu.delegate = self
        }

        if let button = self.statusBarItem.button {
             //button.image = NSImage(named: "Icon")
            button.action = #selector(onClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.updateTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(updateBar), userInfo: nil, repeats: true)

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.updateBar()
        }

    }
    
    @objc func onClick(sender: NSStatusItem) {
        let event = NSApp.currentEvent!
        
        if event.type == NSEvent.EventType.rightMouseUp {
            self.updateStatusBarMenu()
            statusBarItem.menu = statusBarMenu
            statusBarMenu.popUp(positioning: nil,
                                at: NSPoint(x: 0, y: statusBarItem.statusBar!.thickness),
                                in: statusBarItem.button)
            
        } else {
            updateBar()
        }
    }
    
    @objc func menuDidClose(_ menu: NSMenu) {
        statusBarItem.menu = nil
    }
    
    @objc func updateStatusBarMenu() {
        if let item = statusBarMenu.item(at: 0) {
            let last = buildAge(date: lastUpdateDate)
            item.title = "Last updated: \(last)"
        }
    }
    
    func getPref(key: PreferenceField) -> String? {
        let defaults = UserDefaults.standard

        return defaults.object(forKey: key.rawValue) as? String
    }
    
    func setPref(key: PreferenceField, val: String) {
        let defaults = UserDefaults.standard
        defaults.set(val, forKey: key.rawValue)
    }
    
    @objc func settingsNightscoutUrl() {
        let retVal = askForString(title: "Settings", question: "Enter Nightscout URL:", defaultValue: getPref(key: PreferenceField.nightscoutUrl) ?? "")
        if retVal != nil {
            setPref(key: PreferenceField.nightscoutUrl, val: retVal!)
        }
    }
    
    @objc func settingsShowDelta() {
        changeCheckboxSetting(pref: PreferenceField.statusBarShowDelta)
    }
    
    @objc func settingsAlwaysShowAge() {
        changeCheckboxSetting(pref: PreferenceField.statusBarAlwaysShowAge)
    }
    
    func changeCheckboxSetting(pref: PreferenceField) {
        if getCheckboxSetting(pref: pref) {
            setPref(key: pref, val: "false")
        } else {
            setPref(key: pref, val: "true")
        }
        updateCheckboxSettings()
        updateBar()
    }
    
    func updateCheckboxSettings() {
        updateCheckboxSetting(menu: settingsMenu, title: "Show Delta", pref: PreferenceField.statusBarShowDelta)
        updateCheckboxSetting(menu: settingsMenu, title: "Always Show Age", pref: PreferenceField.statusBarAlwaysShowAge)
    }
    
    func updateCheckboxSetting(menu: NSMenu, title: String, pref: PreferenceField) {
        var val = NSControl.StateValue.off
        if getCheckboxSetting(pref: pref) {
            val = NSControl.StateValue.on
        }
        menu.item(withTitle: title)?.state = val
    }
    
    func getCheckboxSetting(pref: PreferenceField) -> Bool {
        return getPref(key: pref) ?? "false" == "true"
    }
    
    func askForString(title: String, question: String, defaultValue: String) -> String? {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.messageText = title
        alert.informativeText = question
        
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = defaultValue
        
        alert.accessoryView = field
        
        let response: NSApplication.ModalResponse = alert.runModal()
        if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
            return field.stringValue
        } else {
            return nil
        }
    }
    
    func getBaseNightscoutUrl() -> String {
        var pref = getPref(key: PreferenceField.nightscoutUrl) ?? "http://localhost"
        if pref.hasSuffix("/") {
            pref.removeLast(1)
        }
        
        if pref.hasSuffix("/api/v1") {
            pref.removeLast(7)
        }
        
        return pref
    }
    
    struct SGVReading: Decodable {
        let _id: String
        let device: String
        let date: Int
        let dateString: String
        let sgv: Int
        let delta: Double
        let direction: String
    }
    
    // Obtains the latest SGV reading and updates the statusbar
    @objc func updateBar() {
        print("Running updateBar")
        if let button = self.statusBarItem.button {
            DispatchQueue.main.async {
                button.title = "..."
            }
        }
        let url = URL(string: getBaseNightscoutUrl() + "/api/v1/entries/sgv.json?count=1")!
        
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            
            print(String(data: data, encoding: .utf8)!)
            let sgvs: [SGVReading] = try! JSONDecoder().decode([SGVReading].self, from: data)
            
            print(sgvs)
            
            let title: String = self.buildBarTitle(reading: sgvs[0])
            print(title)
            
            if let button = self.statusBarItem.button {
                DispatchQueue.main.async {
                    button.title = title
                }
            }
        }
        
        task.resume()
    }
    
    func buildArrow(direction: String) -> String {
        let arrows = [
            "NONE": "⇼",
            "DoubleUp": "▲▲",
            "SingleUp": "▲",
            "FortyFiveUp": "⬈",
            "Flat": "▶",
            "FortyFiveDown": "⬊",
            "SingleDown": "▼",
            "DoubleDown": "▼▼",
            "NOT COMPUTABLE": "-",
            "RATE OUT OF RANGE": "⬍"
        ]
        
        if let a: String = arrows[direction] {
            return a
        } else {
            return ""
        }
    }
    
    func buildDelta(delta: Double) -> String {
        let r: Int = Int(round(delta))
        if r >= 0 {
            return "+\(r)"
        } else {
            return "\(r)"
        }
    }
    
    func buildDate(epoch: Int) -> Date {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch/1000))
        return date
    }
    
    func isAgeOld(date: Date) -> Bool {
        let diffComponents = Calendar.current.dateComponents([.hour, .minute], from: date, to: Date())
        let h = diffComponents.hour!
        let m = diffComponents.minute!
        
        return h > 0 || m > 5
    }
    
    func buildAge(date: Date) -> String {
        let diffComponents = Calendar.current.dateComponents([.hour, .minute], from: date, to: Date())
        let m = diffComponents.minute!
        let h = diffComponents.hour!
        if h > 0 {
            return "\(h)h\(m)m"
        } else {
            return "\(m)m"
        }
    }
    
    func buildBarTitle(reading: SGVReading) -> String {
        let date: Date = buildDate(epoch: reading.date)
        self.lastUpdateDate = date
        
        let arrow: String = buildArrow(direction: reading.direction)
        let delta: String = buildDelta(delta: reading.delta)
        let age: String = buildAge(date: date)
        
        var fmt = "\(reading.sgv) \(arrow)"
        if getCheckboxSetting(pref: PreferenceField.statusBarShowDelta) {
            fmt += " \(delta)"
        }
        
        if getCheckboxSetting(pref: PreferenceField.statusBarAlwaysShowAge) || isAgeOld(date: date) {
            fmt += " \(age)"
        }
        
        return fmt
    }

}

