//
//  ContentView.swift
//  swiftuiTabcell
//
//  Created by wb-zhaozhihui on 2026/4/9.
//

internal import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = FeedScreenViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("模式", selection: modeBinding) {
                    ForEach(FeedScreenViewModel.ProviderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("SwiftUI Tabcell")
            .task {
                if viewModel.items.isEmpty {
                    await viewModel.refreshContent()
                }
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

    private var modeBinding: Binding<FeedScreenViewModel.ProviderMode> {
        Binding(
            get: { viewModel.providerMode },
            set: { newValue in
                Task {
                    await viewModel.changeMode(to: newValue)
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.items.isEmpty {
            if !viewModel.hasLoadedOnce || viewModel.isRefreshing {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch viewModel.listState {
                case .content:
                    FeedStateView(title: "暂无数据", buttonTitle: "重新加载") {
                        Task {
                            await viewModel.refreshContent()
                        }
                    }
                case .empty(let message):
                    FeedStateView(title: message, buttonTitle: "重新加载") {
                        Task {
                            await viewModel.refreshContent()
                        }
                    }
                case .error(let message):
                    FeedStateView(title: message, buttonTitle: "重试") {
                        Task {
                            await viewModel.refreshContent()
                        }
                    }
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.items) { item in
                        item.render()
                            .onAppear {
                                Task {
                                    await viewModel.loadMoreIfNeeded(currentItemID: item.id)
                                }
                            }
                    }

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .refreshable {
                await viewModel.refreshContent()
            }
        }
    }
}

#Preview {
    ContentView()
}
