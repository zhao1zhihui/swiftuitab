//
//  swiftuiTabcellApp.swift
//  swiftuiTabcell
//
//  Created by wb-zhaozhihui on 2026/4/9.
//

import SwiftUI

@main
struct swiftuiTabcellApp: App {
    @StateObject private var session = AppSession.shared
    @StateObject private var router = AppRouter(session: AppSession.shared)

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(session)
                .environmentObject(router)
                .onOpenURL { url in
                    Task {
                        await router.handleURL(url)
                    }
                }
        }
    }
}
