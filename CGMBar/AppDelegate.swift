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
    var lastUpdateDate: Date! = Date()
    
    enum PreferenceField : String {
        case nightscoutUrl
        case deviceFilter
        case statusBarShowDelta
        case statusBarAlwaysShowAge
        case statusBarUseColor
        case statusBarUseGreenColor
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
            settingsMenu.addItem(withTitle: "Set Device Filter", action: #selector(settingsDeviceFilter), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Show Delta", action: #selector(settingsShowDelta), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Always Show Age", action: #selector(settingsAlwaysShowAge), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Use Color", action: #selector(settingsUseColor), keyEquivalent: "")
            settingsMenu.addItem(withTitle: "Use Green Color", action: #selector(settingsUseGreenColor), keyEquivalent: "")
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
        let retVal = askForString(title: "Settings", question: "Enter Nightscout URL:", defaultValue: getPref(key: .nightscoutUrl) ?? "")
        if retVal != nil {
            setPref(key: .nightscoutUrl, val: retVal!)
        }
        updateNightscoutCheckbox(menu: settingsMenu)
    }
    
    @objc func settingsDeviceFilter() {
        let retVal = askForString(title: "Settings", question: "Enter substring of reported device to filter readings for (leave empty for no filter):", defaultValue: getPref(key: .deviceFilter) ?? "")
        if retVal != nil {
            setPref(key: .deviceFilter, val: retVal!)
        }
        updateDeviceFilterCheckbox(menu: settingsMenu)
    }
    
    @objc func settingsShowDelta() {
        changeCheckboxSetting(pref: .statusBarShowDelta)
    }
    
    @objc func settingsAlwaysShowAge() {
        changeCheckboxSetting(pref: .statusBarAlwaysShowAge)
    }
    
    @objc func settingsUseColor() {
        changeCheckboxSetting(pref: .statusBarUseColor)
    }
    
    @objc func settingsUseGreenColor() {
        changeCheckboxSetting(pref: .statusBarUseGreenColor)
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
        updateCheckboxSetting(menu: settingsMenu, title: "Show Delta", pref: .statusBarShowDelta)
        updateCheckboxSetting(menu: settingsMenu, title: "Always Show Age", pref: .statusBarAlwaysShowAge)
        updateCheckboxSetting(menu: settingsMenu, title: "Use Color", pref: .statusBarUseColor)
        updateCheckboxSetting(menu: settingsMenu, title: "Use Green Color", pref: .statusBarUseGreenColor)
        updateNightscoutCheckbox(menu: settingsMenu)
        updateDeviceFilterCheckbox(menu: settingsMenu)
    }
    
    func updateCheckboxSetting(menu: NSMenu, title: String, pref: PreferenceField) {
        var val = NSControl.StateValue.off
        if getCheckboxSetting(pref: pref) {
            val = NSControl.StateValue.on
        }
        menu.item(withTitle: title)?.state = val
    }
    
    func updateNightscoutCheckbox(menu: NSMenu) {
        var val = NSControl.StateValue.off
        if getBaseNightscoutUrl() != "" {
            val = NSControl.StateValue.on
        }
        menu.item(withTitle: "Set Nightscout URL")?.state = val
    }
    
    func updateDeviceFilterCheckbox(menu: NSMenu) {
        var val = NSControl.StateValue.off
        if getDeviceFilter() != "" {
            val = NSControl.StateValue.on
        }
        menu.item(withTitle: "Set Device Filter")?.state = val
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
        var pref = getPref(key: .nightscoutUrl) ?? ""
        if pref.hasSuffix("/") {
            pref.removeLast(1)
        }
        
        if pref.hasSuffix("/api/v1") {
            pref.removeLast(7)
        }
        
        return pref
    }
    
    func getDeviceFilter() -> String {
        return getPref(key: .deviceFilter) ?? ""
    }
    
    struct SGVReading: Decodable {
        let _id: String
        let device: String
        let date: Double
        let dateString: String
        let sgv: Int
        let delta: Double?
        let direction: String?
    }
    
    func showError() {
        if let button = self.statusBarItem.button {
            DispatchQueue.main.async {
                if self.getBaseNightscoutUrl() == "" {
                    button.attributedTitle = self.clr(s: "Right-click to set NS URL", c: NSColor.red)
                } else {
                    button.attributedTitle = self.clr(s: "Error", c: NSColor.red)
                }
            }
        }
    }
    
    // Obtains the latest SGV reading and updates the statusbar
    @objc func updateBar() {
        print("Running updateBar")

        if self.getBaseNightscoutUrl() == "" {
            showError()
            return
        }
        
        let url = URL(string: getBaseNightscoutUrl() + "/api/v1/entries/sgv.json?count=4")!
        
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            if error != nil {
                self.showError()
            }
            guard let data = data else { return }
            
            print(String(data: data, encoding: .utf8)!)
            let sgvs: [SGVReading] = try! JSONDecoder().decode([SGVReading].self, from: data)
            
            print(sgvs)
            
            let filteredSgvs: [SGVReading] = self.filterSgvs(readings: sgvs, deviceFilter: self.getDeviceFilter())
            
            let title: NSAttributedString = self.buildBarTitle(readings: filteredSgvs)
            print(title)
            
            if let button = self.statusBarItem.button {
                DispatchQueue.main.async {
                    button.attributedTitle = title
                }
            }
        }
        
        task.resume()
    }
    
    func clr(s: String, c: NSColor) -> NSAttributedString {
        return NSAttributedString(string: s, attributes: [
            NSAttributedString.Key.foregroundColor: c
        ])
    }
    
    func colorFromSgv(s: String, sgv: Int) -> NSAttributedString {
        if getCheckboxSetting(pref: .statusBarUseColor) {
            if sgv < 80 {
                return clr(s: s, c: NSColor.red)
            } else if sgv >= 180 {
                return clr(s: s, c: NSColor.orange)
            } else if getCheckboxSetting(pref: .statusBarUseGreenColor) {
                return clr(s: s, c: NSColor.green)
            }
        }
        return NSAttributedString(string: s)
    }
    
    func colorFromDelta(s: String, delta: Double) -> NSAttributedString {
        if getCheckboxSetting(pref: .statusBarUseColor) {
            if abs(delta) >= 12 {
                return clr(s: s, c: NSColor.red)
            } else if abs(delta) >= 8  {
                return clr(s: s, c: NSColor.orange)
            } else if getCheckboxSetting(pref: .statusBarUseGreenColor) {
                return clr(s: s, c: NSColor.green)
            }
        }
        return NSAttributedString(string: s)
    }
    
    func colorFromAge(s: String, date: Date) -> NSAttributedString {
        if getCheckboxSetting(pref: .statusBarUseColor) {
            if isAgeOld(date: date) {
                return clr(s: s, c: NSColor.orange)
            } else if getCheckboxSetting(pref: .statusBarUseGreenColor) {
                return clr(s: s, c: NSColor.green)
            }
        }
        return NSAttributedString(string: s)
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
    
    func buildDirection(delta: Double) -> String {
        if (delta <= -3.5 * 5) {
            return "DoubleDown";
        } else if (delta <= -2 * 5) {
            return "SingleDown";
        } else if (delta <= -1 * 5) {
            return "FortyFiveDown";
        } else if (delta <= 1 * 5) {
            return "Flat";
        } else if (delta <= 2 * 5) {
            return "FortyFiveUp";
        } else if (delta <= 3.5 * 5) {
            return "SingleUp";
        } else if (delta <= 40 * 5) {
            return "DoubleUp";
        }
        return "NONE";
    }
    
    func buildDelta(delta: Double) -> String {
        let r: Int = Int(round(delta))
        if r >= 0 {
            return "+\(r)"
        } else {
            return "\(r)"
        }
    }
    
    func buildDate(epoch: Double) -> Date {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch/1000))
        return date
    }
    
    func isAgeOld(date: Date) -> Bool {
        let diffComponents = Calendar.current.dateComponents([.hour, .minute], from: date, to: Date())
        let h = diffComponents.hour!
        let m = diffComponents.minute!
        
        return h > 0 || m > 5
    }
    
    func shouldShowAge(date: Date) -> Bool {
        return getCheckboxSetting(pref: .statusBarAlwaysShowAge) || isAgeOld(date: date)
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
    
    func matchesDeviceFilter(r: SGVReading, deviceFilter: String) -> Bool {
        return deviceFilter == "" || r.device.contains(deviceFilter)
    }
    
    func filterSgvs(readings: [SGVReading], deviceFilter: String) -> [SGVReading] {
        var ret: [SGVReading] = [];
        for (i, r) in readings.enumerated() {
            if (matchesDeviceFilter(r: r, deviceFilter: deviceFilter)) {
                ret.append(r);
            }
        }
        
        return ret
    }
    
    func buildBarTitle(readings: [SGVReading]) -> NSAttributedString {
        if (readings.count == 0) {
            let m = NSMutableAttributedString()
            m.append(NSAttributedString(string:"UNKNOWN"))
            return m
        }
        let reading: SGVReading = readings[0]
        var delta = Double(reading.delta ?? 0)
        var direction = reading.direction ?? "NONE"
        
        // if delta is not present in nightscout, compute it
        if (reading.delta == nil && readings.count >= 2) {
            delta = Double(reading.sgv - readings[1].sgv)
            if (readings[1].sgv == reading.sgv && readings[1].device != reading.device && readings.count >= 3) {
                delta = Double(reading.sgv - readings[2].sgv)
            }
        }
        
        if (reading.direction == nil || reading.direction == "NONE" || reading.direction == "") {
            direction = buildDirection(delta: delta)
        }
        
        return buildBarTitleString(direction: direction, deltaV: delta, reading: reading)
    }
    
    func buildBarTitleString(direction: String, deltaV: Double, reading: SGVReading) -> NSAttributedString {
        let date: Date = buildDate(epoch: reading.date)
        self.lastUpdateDate = date
        
        let arrow: String = buildArrow(direction: direction)
        let delta: String = buildDelta(delta: deltaV)
        let age: String = buildAge(date: date)
        
        let fmt = NSMutableAttributedString()
        
        fmt.append(colorFromSgv(s: "\(reading.sgv)", sgv: reading.sgv))
        
        if getCheckboxSetting(pref: .statusBarShowDelta) {
            fmt.append(colorFromDelta(s: " \(arrow) \(delta)", delta: deltaV))
        } else {
            fmt.append(colorFromDelta(s: " \(arrow)", delta: deltaV))
        }
        
        if shouldShowAge(date: date) {
            fmt.append(colorFromAge(s: " \(age)", date: date))
        }
        
        return fmt
    }

}

