//
//  SwiftCloudKitDemoApp.swift
//  SwiftCloudKitDemo
//
//  Created by Daniel  Gushchyan on 1/8/25.
//

import SwiftUI

@main
struct SwiftCloudKitDemoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
