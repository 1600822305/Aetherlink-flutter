Pod::Spec.new do |s|
  s.name             = 'native_keyboard_height'
  s.version          = '0.1.0'
  s.summary          = 'Native keyboard height events for Flutter (keyboardWillShow/keyboardWillHide).'
  s.description      = <<-DESC
  Provides native keyboard height events that fire BEFORE the OS keyboard
  animation starts, with the final keyboard height. Matches Capacitor's
  Keyboard plugin behavior.
                       DESC
  s.homepage         = 'https://github.com/1600822305/Aetherlink-flutter'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'AetherLink' => 'dev@aetherlink.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'
end
