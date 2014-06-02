Pod::Spec.new do |s|
  s.name     = 'FXParser'
  s.version  = '1.1'
  s.license  = 'zlib'
  s.summary  = 'FXParser is a text parsing engine for iOS and Mac OS to simplify the consumption of text-based languages and data formats, e.g. JSON.'
  s.homepage = 'https://github.com/nicklockwood/FXParser'
  s.social_media_url = 'https://twitter.com/nicklockwood'
  s.authors  = 'Nick Lockwood'
  s.source   = { :git => 'https://github.com/nicklockwood/FXParser.git', :tag => '1.1' }
  s.source_files = 'FXParser'
  s.requires_arc = true
  s.ios.deployment_target = '4.3'
  s.osx.deployment_target = '10.6'
end