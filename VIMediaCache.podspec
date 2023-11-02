Pod::Spec.new do |s|
    s.name = 'VIMediaCache'
    s.version = '1.0.0'
    s.license = 'MIT'
    s.summary = 'VIMediaCache is a tool to cache media file while play media using AVPlayer'
    s.homepage = 'https://github.com/Mrxu2/VIMediaCache'
    s.author = { 'Vito' => '13779928250@163.com' }
    s.source = { :git => 'https://github.com/Mrxu2/VIMediaCache.git', :tag => s.version.to_s }
    s.platform = :ios, '8.0'
    s.source_files = 'VIMediaCache/*.{h,m}', 'VIMediaCache/**/*.{h,m}'
    s.frameworks = 'MobileCoreServices', 'AVFoundation'
    s.requires_arc = true
end

