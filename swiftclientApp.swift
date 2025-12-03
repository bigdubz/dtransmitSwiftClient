//
//  swiftclientApp.swift
//  swiftclient
//
//  Created by Ahmad Aljobouri on 24/11/2025.
//

import SwiftUI

@main
struct swiftclientApp: App {
    init() {
        UITextView.appearance().backgroundColor = .clear
        UITextView.appearance().isOpaque = false

        UIScrollView.appearance().backgroundColor = .clear
        UIScrollView.appearance().isOpaque = false
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
