#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mercury_js.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mercury_js'
  s.version          = '0.1.0'
  s.summary          = 'A W3C standard compliant library with integrated JavaScript engine & extension utils based on Flutter.'
  s.description      = <<-DESC
  Mercury is a W3C standards-compliant library with integrated JavaScript engine & extension utils based on Flutter, allowing JavaScript to run natively within Flutter.
                       DESC
  s.homepage         = 'https://openwebf.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'WebF' => 'dongtiangche@outlook.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'FlutterMacOS'
  s.vendored_libraries = 'libmercury_js.dylib', 'libquickjs.dylib'
  s.prepare_command = 'bash prepare.sh'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
