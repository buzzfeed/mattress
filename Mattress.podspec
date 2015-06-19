Pod::Spec.new do |s|
  s.name = 'Mattress'
  s.version = '1.0'
  s.license = 'MIT'
  s.summary = 'iOS Offline Caching for Web Content'
  s.homepage = 'https://github.com/buzzfeed/Mattress'
  s.social_media_url = 'http://twitter.com/buzzfeed'
  s.authors = { 'David Mauro' => 'david.mauro@buzzfeed.com' }
  s.source = { :git => 'https://github.com/buzzfeed/Mattress.git', :tag => s.version }

  s.ios.deployment_target = '8.0'

  s.source_files = 'Source/*.swift'

  s.requires_arc = true
end
