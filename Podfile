platform :ios, '16.0'
inhibit_all_warnings!

target 'swiftuiTabcell' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for swiftuiTabcell
  pod 'Moya'
  pod 'Alamofire'
  pod 'KafkaRefresh'
  pod 'SDWebImage'
  pod 'SnapKit'
  pod "SwiftUIRefresh"

  target 'swiftuiTabcellTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'swiftuiTabcellUITests' do
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS'] = 'YES'
  end

  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
      config.build_settings['CODE_SIGN_IDENTITY'] = ''
      config.build_settings['CLANG_ENABLE_MODULE_VERIFIER'] = 'YES'
    end
  end
end
