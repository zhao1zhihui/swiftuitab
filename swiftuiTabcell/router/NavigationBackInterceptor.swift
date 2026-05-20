import SwiftUI
import UIKit

/// SwiftUI iOS16 没有公开的侧滑返回开关。
/// 这里用 UIKit 手势代理在 shouldBegin 阶段拦截，做到“侧滑刚开始就弹确认”，而不是滑完后再回滚。
/// 注意：iOS 官方公开的是 UINavigationController 的边缘返回手势；全屏返回通常来自业务或三方库额外挂的 Pan。
private struct InteractivePopGestureConfigurator: UIViewControllerRepresentable {
    let isEnabled: Bool
    let horizontalScrollHandoff: HorizontalScrollBackHandoff
    let shouldBegin: (() -> Bool)?

    func makeUIViewController(context: Context) -> Controller {
        Controller(
            isEnabled: isEnabled,
            horizontalScrollHandoff: horizontalScrollHandoff,
            shouldBegin: shouldBegin
        )
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isEnabled = isEnabled
        controller.horizontalScrollHandoff = horizontalScrollHandoff
        controller.shouldBegin = shouldBegin
        controller.applyIfPossible()
    }

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        var isEnabled: Bool
        var horizontalScrollHandoff: HorizontalScrollBackHandoff
        var shouldBegin: (() -> Bool)?
        private var originalDelegates: [ObjectIdentifier: UIGestureRecognizerDelegate] = [:]
        private var latestTouchViews: [ObjectIdentifier: UIView] = [:]
        private var armedLeadingScrollViews: [ObjectIdentifier: Date] = [:]

        init(isEnabled: Bool,
             horizontalScrollHandoff: HorizontalScrollBackHandoff,
             shouldBegin: (() -> Bool)?) {
            self.isEnabled = isEnabled
            self.horizontalScrollHandoff = horizontalScrollHandoff
            self.shouldBegin = shouldBegin
            super.init(nibName: nil, bundle: nil)
            view.isHidden = true
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyIfPossible()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            applyIfPossible()
        }

        func applyIfPossible() {
            // SwiftUI 有时会在更新周期后重新配置导航控制器，所以异步到下一轮主队列更稳。
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                guard let navigationController = self.navigationController,
                      let edgeGesture = navigationController.interactivePopGestureRecognizer else {
                    return
                }
                self.configurePopGestures(on: navigationController, edgeGesture: edgeGesture)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard isEnabled else {
                return false
            }

            // 根页面没有可返回的 ViewController，直接拒绝手势，避免空栈侧滑产生异常状态。
            guard let navigationController, navigationController.viewControllers.count > 1 else {
                return false
            }

            if let originalResult = originalDelegate(for: gestureRecognizer)?.gestureRecognizerShouldBegin?(gestureRecognizer),
               !originalResult {
                return false
            }

            if isNavigationBackPan(gestureRecognizer, in: navigationController),
               !isRightwardPanIfNeeded(gestureRecognizer) {
                return false
            }

            if let pan = gestureRecognizer as? UIPanGestureRecognizer,
               isNavigationBackPan(pan, in: navigationController),
               !shouldBackPanBeginConsideringHorizontalScroll(pan) {
                return false
            }

            return shouldBegin?() ?? true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            originalDelegate(for: gestureRecognizer)?
                .gestureRecognizer?(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            latestTouchViews[ObjectIdentifier(gestureRecognizer)] = touch.view
            return originalDelegate(for: gestureRecognizer)?
                .gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? true
        }

        private func configurePopGestures(on navigationController: UINavigationController,
                                          edgeGesture: UIGestureRecognizer) {
            edgeGesture.isEnabled = isEnabled
            takeOverDelegate(of: edgeGesture)

            // 全屏返回通常是额外挂在 UINavigationController.view 上的 UIPanGestureRecognizer。
            // 只接管导航容器级手势，不扫描业务 View 层级，避免误伤列表、轮播图等横向滑动。
            navigationController.view.gestureRecognizers?
                .compactMap { $0 as? UIPanGestureRecognizer }
                .filter { $0 !== edgeGesture }
                .forEach { gesture in
                    gesture.isEnabled = isEnabled
                    takeOverDelegate(of: gesture)
                }
        }

        private func takeOverDelegate(of gesture: UIGestureRecognizer) {
            let identifier = ObjectIdentifier(gesture)
            if originalDelegates[identifier] == nil,
               let delegate = gesture.delegate,
               (delegate as AnyObject) !== self {
                originalDelegates[identifier] = delegate
            }
            gesture.delegate = self
        }

        private func originalDelegate(for gesture: UIGestureRecognizer) -> UIGestureRecognizerDelegate? {
            originalDelegates[ObjectIdentifier(gesture)]
        }

        private func isNavigationBackPan(_ gestureRecognizer: UIGestureRecognizer,
                                         in navigationController: UINavigationController) -> Bool {
            if gestureRecognizer === navigationController.interactivePopGestureRecognizer {
                return true
            }

            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            return pan.view === navigationController.view
        }

        private func isRightwardPanIfNeeded(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
                return true
            }

            let velocity = pan.velocity(in: pan.view)
            if abs(velocity.x) > abs(velocity.y) {
                return velocity.x > 0
            }

            let translation = pan.translation(in: pan.view)
            return translation.x >= 0
        }

        private func shouldBackPanBeginConsideringHorizontalScroll(_ pan: UIPanGestureRecognizer) -> Bool {
            guard let touchView = latestTouchViews[ObjectIdentifier(pan)],
                  let scrollView = nearestHorizontalScrollView(from: touchView)
            else {
                return true
            }

            guard isRightwardPanIfNeeded(pan) else {
                return true
            }

            // 横向 ScrollView 没到最左边时，右滑应该先还给横向列表。
            // 例如签到日历、运营横滑卡片、轮播图，否则全屏返回会抢掉业务滑动。
            if !isAtLeadingEdge(scrollView) {
                clearArmedState(for: scrollView)
                return false
            }

            switch horizontalScrollHandoff {
            case .directAtLeadingEdge:
                clearArmedState(for: scrollView)
                return true
            case .secondSwipeAtLeadingEdge:
                return consumeOrArmSecondSwipe(for: scrollView)
            }
        }

        private func nearestHorizontalScrollView(from view: UIView) -> UIScrollView? {
            var current: UIView? = view

            while let view = current {
                if let scrollView = view as? UIScrollView,
                   scrollView.contentSize.width > scrollView.bounds.width + 1 {
                    return scrollView
                }
                current = view.superview
            }

            return nil
        }

        private func isAtLeadingEdge(_ scrollView: UIScrollView) -> Bool {
            let leadingOffset = -scrollView.adjustedContentInset.left
            return scrollView.contentOffset.x <= leadingOffset + 1
        }

        private func consumeOrArmSecondSwipe(for scrollView: UIScrollView) -> Bool {
            let identifier = ObjectIdentifier(scrollView)
            let now = Date()

            if let armedAt = armedLeadingScrollViews[identifier],
               now.timeIntervalSince(armedAt) < 1.2 {
                armedLeadingScrollViews[identifier] = nil
                return true
            }

            armedLeadingScrollViews[identifier] = now
            return false
        }

        private func clearArmedState(for scrollView: UIScrollView) {
            armedLeadingScrollViews[ObjectIdentifier(scrollView)] = nil
        }
    }
}

extension View {
    /// 页面级侧滑返回开关。
    /// 业务判断仍交给 Router，UIKit 这里只负责在手势开始前询问是否允许开始。
    func interactivePopGestureEnabled(_ isEnabled: Bool,
                                      horizontalScrollHandoff: HorizontalScrollBackHandoff = .directAtLeadingEdge,
                                      shouldBegin: (() -> Bool)? = nil) -> some View {
        background(
            InteractivePopGestureConfigurator(
                isEnabled: isEnabled,
                horizontalScrollHandoff: horizontalScrollHandoff,
                shouldBegin: shouldBegin
            )
        )
    }
}
