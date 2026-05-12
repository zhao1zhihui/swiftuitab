import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            AppNavigationStack(path: $router.feedPath, root: FeedTabRootView())
                .tabItem {
                    Label(AppTab.feed.title, systemImage: AppTab.feed.systemImage)
                }
                .tag(AppTab.feed)

            AppNavigationStack(path: $router.discoverPath, root: DiscoverTabRootView())
                .tabItem {
                    Label(AppTab.discover.title, systemImage: AppTab.discover.systemImage)
                }
                .tag(AppTab.discover)

            AppNavigationStack(path: $router.accountPath, root: AccountTabRootView())
                .tabItem {
                    Label(AppTab.account.title, systemImage: AppTab.account.systemImage)
                }
                .tag(AppTab.account)
        }
    }
}

private struct AppNavigationStack<Root: View>: View {
    @Binding var path: [AppRoute]
    let root: Root

    var body: some View {
        NavigationStack(path: $path) {
            root
                .navigationDestination(for: AppRoute.self) { route in
                    RouteDestinationView(route: route)
                }
        }
    }
}
