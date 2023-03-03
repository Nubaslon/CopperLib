#
# Be sure to run `pod lib lint CopperLib.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CopperLib'
  s.version          = '0.0.1'
  s.summary          = 'A short description of CopperLib.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/Evgeny Antropov/CopperLib'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Evgeny Antropov' => 'Evgeny.Antropov@raiffeisen.ru' }
  s.source           = { :git => 'https://github.com/antigp/CopperLib.git', :branch => "master" }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.default_subspec = 'Core'

  s.ios.deployment_target = '14.0'
  s.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'FROM_COCOAPODS',
  }

  s.subspec 'Core' do |subspec|
    subspec.source_files        = 'Sources/CopperLib/**/*.swift'

    subspec.dependency 'PeerTalk', '~> 0.1.0'
    subspec.dependency 'CopperLib/Proto'
    subspec.dependency 'CopperLib/CopperPlugin'
  end

  s.subspec 'Proto' do |subspec|
    subspec.source_files = 'Sources/Proto/**/*.swift'
    subspec.dependency 'SwiftProtobuf'
  end

  s.subspec 'CopperEncryptor' do |subspec|
    subspec.source_files        = 'Sources/CopperEncryptor/**/*.swift'

    subspec.dependency 'CopperLib/CopperEncryptorChaCha20'
  end

  s.subspec 'CopperEncryptorChaCha20' do |subspec|
    subspec.source_files        = 'Sources/CopperEncryptorChaCha20/**/*.{c,h}'
    subspec.public_header_files = 'Sources/CopperEncryptorChaCha20/**/*.h'
  end

  s.subspec 'CopperPlugin' do |subspec|
    subspec.source_files        = 'Sources/CopperPlugin/**/*.swift'
    subspec.dependency 'CopperLib/Proto'
  end

  s.subspec 'LoggerPlugin' do |subspec|
    subspec.source_files        = 'Sources/LoggerPlugin/**/*.{swift,h}'
    subspec.public_header_files = 'Sources/LoggerPlugin/**/*.h'
    subspec.dependency 'Logging'
    subspec.dependency 'CopperLib/CopperPlugin'
    subspec.dependency 'CopperLib/Proto'
    subspec.dependency 'CopperLib/CopperEncryptor'
  end

  s.subspec 'NetworkPlugin' do |subspec|
    subspec.source_files        = 'Sources/NetworkPlugin/**/*.{swift,h}'
    subspec.public_header_files = 'Sources/NetworkPlugin/**/*.h'
    subspec.dependency 'CopperLib/CopperPlugin'
    subspec.dependency 'CopperLib/Proto'
    subspec.dependency 'CopperLib/CopperEncryptor'
  end
end
