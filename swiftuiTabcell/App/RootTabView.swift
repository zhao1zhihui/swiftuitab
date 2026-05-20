import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            AppNavigationStack(tab: .feed, path: navigationPath(for: .feed), root: FeedTabRootView())
                .tabItem {
                    Label(AppTab.feed.title, systemImage: AppTab.feed.systemImage)
                }
                .tag(AppTab.feed)

            AppNavigationStack(tab: .discover, path: navigationPath(for: .discover), root: DiscoverTabRootView())
                .tabItem {
                    Label(AppTab.discover.title, systemImage: AppTab.discover.systemImage)
                }
                .tag(AppTab.discover)

            AppNavigationStack(tab: .account, path: navigationPath(for: .account), root: AccountTabRootView())
                .tabItem {
                    Label(AppTab.account.title, systemImage: AppTab.account.systemImage)
                }
                .tag(AppTab.account)
        }
        .alert(item: $router.backAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                primaryButton: .default(Text("继续返回")) {
                    router.confirmBlockedBack()
                },
                secondaryButton: .cancel(Text("留在此页")) {
                    router.cancelBlockedBack()
                }
            )
        }
    }

    private func navigationPath(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: {
                switch tab {
                case .feed:
                    return router.feedPath
                case .discover:
                    return router.discoverPath
                case .account:
                    return router.accountPath
                }
            },
            set: { newPath in
                router.applyNavigationPath(newPath, on: tab)
            }
        )
    }
}

private struct AppNavigationStack<Root: View>: View {
    let tab: AppTab
    @Binding var path: [AppRoute]
    let root: Root
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestinationView(route: route)
                        .interactivePopGestureEnabled(
                            true,
                            horizontalScrollHandoff: route.backPolicy.horizontalScrollHandoff
                        ) {
                            routerShouldBeginInteractiveBack(from: route)
                        }
                }
        }
    }

    private func routerShouldBeginInteractiveBack(from route: AppRoute) -> Bool {
        return router.shouldBeginInteractiveBack(from: route, on: tab)
    }
}
