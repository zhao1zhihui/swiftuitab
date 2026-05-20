#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-swiftuiTabcell}"
EXIT_CODE=0

# 架构边界检查脚本。
# 这些规则先覆盖最容易把 MVVM 基座用歪的地方，后续可以继续接 SwiftLint/自定义 Build Phase。
check_no_ui_imports() {
  local pattern="$1"
  local label="$2"
  local matches

  matches="$(rg -n '^import (SwiftUI|UIKit)$' "$ROOT" -g "$pattern" || true)"
  if [[ -n "$matches" ]]; then
    echo "error: $label 不应该直接 import SwiftUI/UIKit"
    echo "$matches"
    EXIT_CODE=1
  fi
}

check_no_direct_imports() {
  local pattern="$1"
  local label="$2"
  local import_regex="$3"
  local message="$4"
  local matches

  matches="$(rg -n "^import (${import_regex})$" "$ROOT" -g "$pattern" || true)"
  if [[ -n "$matches" ]]; then
    echo "error: $label $message"
    echo "$matches"
    EXIT_CODE=1
  fi
}

check_no_forbidden_usage() {
  local pattern="$1"
  local label="$2"
  local usage_text="$3"
  local message="$4"
  local matches

  matches="$(rg -n -F "$usage_text" "$ROOT" -g "$pattern" || true)"
  if [[ -n "$matches" ]]; then
    echo "error: $label $message"
    echo "$matches"
    EXIT_CODE=1
  fi
}

check_no_ui_imports '*ViewModel.swift' 'ViewModel'
check_no_ui_imports '*Repository.swift' 'Repository'
check_no_ui_imports 'Network/*.swift' 'Network'
check_no_ui_imports 'router/AppRoute.swift' 'AppRoute'
check_no_ui_imports 'router/AppRouter.swift' 'AppRouter'
check_no_ui_imports 'router/AppRouteRegistry.swift' 'AppRouteRegistry'

# ViewModel 只能依赖 Provider/UseCase/Repository 协议，不应该自己拼 URL 或直接访问 URLSession。
check_no_direct_imports '*ViewModel.swift' 'ViewModel' 'Alamofire|Moya' '不应该直接依赖三方网络框架'
check_no_forbidden_usage '*ViewModel.swift' 'ViewModel' 'URLSession' '不应该直接访问网络基础设施'
check_no_forbidden_usage '*ViewModel.swift' 'ViewModel' 'NetworkService' '不应该直接访问网络基础设施'
check_no_forbidden_usage '*ViewModel.swift' 'ViewModel' 'URLRequest' '不应该直接访问网络基础设施'

# SwiftUI View 的导航统一走 AppRouter，避免业务页面自己维护多套导航状态。
check_no_forbidden_usage '*View.swift' 'View' 'NavigationLink(' '不应该绕过 AppRouter 直接创建 NavigationLink'
check_no_forbidden_usage '*Views.swift' 'View' 'NavigationLink(' '不应该绕过 AppRouter 直接创建 NavigationLink'

exit "$EXIT_CODE"
