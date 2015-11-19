Pod::Spec.new do |s|
  s.name = 'Mattress'
  s.version = '1.0.1'
  s.license = 'MIT'
  s.summary = 'iOS Offline Caching for Web Content'
  s.homepage = 'https://github.com/buzzfeed/mattress'
  s.social_media_url = 'http://twitter.com/buzzfeed'
  s.authors = { 'David Mauro' => 'david.mauro@buzzfeed.com',
		'Kevin Lord'  => 'kevin.lord@buzzfeed.com' }
  s.source = { :git => 'https://github.com/buzzfeed/mattress.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'Source/*.swift', 'Source/Extensions/*.swift'

  s.preserve_paths = 'CommonCrypto/*'
  s.xcconfig = {
    'SWIFT_INCLUDE_PATHS[sdk=iphoneos*]' => '$(SRCROOT)/Mattress/CommonCrypto/iphoneos',
    'SWIFT_INCLUDE_PATHS[sdk=iphonesimulator*]' => '$(SRCROOT)/Mattress/CommonCrypto/iphonesimulator',
    'SWIFT_INCLUDE_PATHS[sdk=macosx*]' => '$(SRCROOT)/Mattress/CommonCrypto/macosx'
   }
  s.requires_arc = true
end
