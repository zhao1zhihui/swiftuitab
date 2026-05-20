//
//  ContentView.swift
//  swiftuiTabcell
//
//  Created by wb-zhaozhihui on 2026/4/9.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: FeedScreenViewModel
    private let pagingStyle = PagingContainerStyle.feedDefault
    @EnvironmentObject private var router: AppRouter

    init(viewModel: FeedScreenViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        PagingContainer(
            items: viewModel.items,
            phase: viewModel.pagePhase,
            canLoadMore: viewModel.canLoadMore,
            isRefreshing: viewModel.isRefreshing,
            isLoadingMore: viewModel.isLoadingMore,
            loadMoreResetToken: viewModel.loadMoreResetToken,
            style: pagingStyle,
            onRefresh: {
                await viewModel.refreshContent()
            },
            onRetry: {
                await viewModel.refreshContent()
            },
            onLoadMore: {
                await viewModel.loadMoreIfNeeded()
            },
            rowContent: { item in
                FeedRowView(row: item)
            }
        )
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("设置") {
                    router.push(.settings)
                }
            }
        }
        .pagingContainerPadding(16)
        .pagingStateViewStyle(.default)
        .task {
            await viewModel.refreshContentIfNeeded()
        }
        .alert(item: $viewModel.alertMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}
