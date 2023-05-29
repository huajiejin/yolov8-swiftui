//
//  YOLOv8App.swift
//  YOLOv8
//
//  Created by Jin on 2023-05-29.
//

import SwiftUI

@main
struct YOLOv8App: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
