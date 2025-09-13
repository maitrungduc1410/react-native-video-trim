require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "VideoTrim"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/maitrungduc1410/react-native-video-trim.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.private_header_files = "ios/**/*.h"

  s.dependency "ffmpeg-mobile-#{ENV['FFMPEGKIT_PACKAGE'] || 'min'}", ENV['FFMPEGKIT_PACKAGE_VERSION'] || '~> 6.0'

  s.frameworks = 'AVFoundation', 'AVKit', 'UIKit', 'Photos'

 install_modules_dependencies(s)
end
