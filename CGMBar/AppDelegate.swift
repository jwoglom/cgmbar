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
    var updateTimer: Timer!
    
    var lastUpdateDate: Date!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        self.statusBarMenu = NSMenu(title: "CGMBar")
        if let menu = self.statusBarMenu {
            menu.addItem(withTitle: "Last updated: unknown", action: nil, keyEquivalent: "")
            menu.addItem(withTitle: "Update Now", action: #selector(updateBar), keyEquivalent: "u")
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            menu.delegate = self
        }

        if let button = self.statusBarItem.button {
             //button.image = NSImage(named: "Icon")
            button.action = #selector(onClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.updateTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(updateBar), userInfo: nil, repeats: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
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
            let last = buildAge(date: lastUpdateDate, always: true)
            item.title = "Last updated: \(last)"
        }
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
        let url = URL(string: "http://127.0.0.1:1337/api/v1/entries/sgv.json?count=1")!
        
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
    
    func buildAge(date: Date, always: Bool) -> String {
        let diffComponents = Calendar.current.dateComponents([.hour, .minute], from: date, to: Date())
        let m = diffComponents.minute!
        let h = diffComponents.hour!
        if h > 0 {
            return "\(h)h\(m)m"
        } else if m > 5 || always {
            return "\(m)m"
        } else {
            return ""
        }
    }
    
    func buildBarTitle(reading: SGVReading) -> String {
        let date: Date = buildDate(epoch: reading.date)
        self.lastUpdateDate = date
        
        let arrow: String = buildArrow(direction: reading.direction)
        let delta: String = buildDelta(delta: reading.delta)
        let age: String = buildAge(date: date, always: false)
        return "\(reading.sgv) \(arrow) \(delta) \(age)"
    }

}

