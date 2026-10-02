#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_webrtc'
  s.version          = '1.6.2'
  s.summary          = 'Flutter WebRTC plugin for iOS.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'https://github.com/cloudwebrtc/flutter-webrtc'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CloudWebRTC' => 'duanweiwei1982@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_webrtc/Sources/flutter_webrtc/**/*.{h,m,mm,cpp}', '../common/rnnoise/rnnoise_capture_processor.{h,cc}', '../common/rnnoise/public_include/*.h', '../common/rnnoise/upstream/include/*.h', '../common/rnnoise/upstream/src/*.{h,c}'
  s.public_header_files = 'flutter_webrtc/Sources/flutter_webrtc/include/flutter_webrtc/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'WebRTC-SDK', '150.7871.01'
  s.ios.deployment_target = '13.0'
  s.static_framework = true
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../common/rnnoise/public_include" "${PODS_TARGET_SRCROOT}/../common/rnnoise/upstream/include"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/flutter_webrtc/Sources/flutter_webrtc/include/flutter_webrtc"'
  }
  s.libraries = 'c++'
end
