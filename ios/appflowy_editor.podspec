Pod::Spec.new do |s|
  s.name = 'appflowy_editor'
  s.version = '6.1.0'
  s.summary = 'Native rich text paste menu for AppFlowy Editor.'
  s.description = 'Preserves clipboard HTML through user-initiated iOS paste actions.'
  s.homepage = 'https://github.com/AppFlowy-IO/appflowy-editor'
  s.license = { :file => '../LICENSE' }
  s.author = { 'AppFlowy' => 'support@appflowy.io' }
  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.swift_version = '5.0'
end
