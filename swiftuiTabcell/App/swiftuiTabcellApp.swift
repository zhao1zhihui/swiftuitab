//
//  swiftuiTabcellApp.swift
//  swiftuiTabcell
//
//  Created by wb-zhaozhihui on 2026/4/9.
//

import SwiftUI

@main
struct swiftuiTabcellApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(dependencies)
                .environmentObject(dependencies.session)
                .environmentObject(dependencies.router)
                .onOpenURL { url in
                    Task {
                        await dependencies.router.handleURL(url)
                    }
                }
                .task {
                    // 启动后从 TokenStore 恢复登录态；View 不关心 token 来自 Keychain 还是内存。
                    await dependencies.session.restoreSession()
                }
        }
    }
}
