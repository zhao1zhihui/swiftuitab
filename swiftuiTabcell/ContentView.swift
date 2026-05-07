//
//  ContentView.swift
//  swiftuiTabcell
//
//  Created by wb-zhaozhihui on 2026/4/9.
//

 import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FeedScreenViewModel()
    private let pagingStyle = PagingContainerStyle.feedDefault

    var body: some View {
        NavigationStack {
            PagingContainer(
                items: viewModel.items,
                phase: viewModel.pagePhase,
                canLoadMore: viewModel.canLoadMore,
                isLoadingMore: viewModel.isLoadingMore,
                style: pagingStyle,
                onRefresh: {
                    await viewModel.refreshContent()
                },
                onRetry: {
                    await viewModel.refreshContent()
                },
                onLoadMoreTrigger: {
                    viewModel.triggerLoadMoreIfNeeded()
                },
                onDisappear: {
                    viewModel.cancelPagingTasks()
                },
                rowContent: { item in
                    FeedRowView(row: item)
                }
            )
            .navigationTitle("SwiftUI Tabcell")
            .pagingContainerPadding(16)
            .pagingStateViewStyle(.default)
            .task {
                viewModel.startInitialLoadIfNeeded()
            }
            .alert(item: $viewModel.alertMessage) { message in
                Alert(
                    title: Text("提示"),
                    message: Text(message.message),
                    dismissButton: .default(Text("知道了"))
                )
            }
        }
    }
}

#Preview {
    ContentView()
}
