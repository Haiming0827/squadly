# Run with xcodeproj 1.27.0 available. Project setup is repeatable and preserves
# the host's existing targets/settings. No signing identity is created here.
require 'xcodeproj'
require 'pathname'

root = File.expand_path('../..', __dir__)
[
  ['ios', 'com.squadly.squadly', 'squadly'],
  ['integration_test/ios', 'com.example.squadlyIntegrationTest', 'squadly-test']
].each do |relative, bundle, scheme|
  base = File.join(root, relative)
  project = Xcodeproj::Project.open(File.join(base, 'Runner.xcodeproj'))
  app = project.targets.find { |t| t.name == 'Runner' }
  raise 'Runner target missing' unless app
  group_id = "group.#{bundle}.widgets"
  widget_path = Pathname.new(File.join(root, 'ios/SquadPhotoWidget')).relative_path_from(Pathname.new(base)).to_s
  source_group = project.main_group.groups.find { |g| g.name == 'SquadPhotoWidget' } || project.main_group.new_group('SquadPhotoWidget', widget_path)
  source_group.path = widget_path
  source = source_group.files.find { |f| f.path == 'SquadPhotoWidget.swift' } || source_group.new_file('SquadPhotoWidget.swift')
  ['Info.plist', 'SquadPhotoWidget.entitlements'].each { |name| source_group.new_file(name) unless source_group.files.any? { |f| f.path == name } }
  widget = project.targets.find { |t| t.name == 'SquadPhotoWidget' } || project.new_target(:app_extension, 'SquadPhotoWidget', :ios, '15.0')
  widget.add_file_references([source]) unless widget.source_build_phase.files_references.include?(source)
  app.add_dependency(widget) unless app.dependencies.any? { |d| d.target == widget }
  embed = app.copy_files_build_phases.find { |p| p.name == 'Embed Photo Widget' } || app.new_copy_files_build_phase('Embed Photo Widget')
  embed.dst_subfolder_spec = '13'
  # Flutter's Thin Binary consumes Info.plist; embedding an extension after
  # that phase creates an Xcode dependency cycle through the app bundle.
  app.build_phases.delete(embed)
  thin = app.build_phases.find { |phase| phase.respond_to?(:name) && phase.name == 'Thin Binary' }
  app.build_phases.insert(thin ? app.build_phases.index(thin) : 0, embed)
  unless embed.files_references.include?(widget.product_reference)
    build_file = embed.add_file_reference(widget.product_reference, true)
    build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
  end
  package_path = Pathname.new(File.join(root, 'packages/squadly_widget_bridge/ios/squadly_widget_bridge')).relative_path_from(Pathname.new(base)).to_s
  package = project.root_object.package_references.find { |p| p.respond_to?(:relative_path) && p.relative_path == package_path }
  unless package
    package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    package.relative_path = package_path
    project.root_object.package_references << package
  end
  unless widget.package_product_dependencies.any? { |d| d.product_name == 'SquadlyWidgetCore' }
    product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    product.product_name = 'SquadlyWidgetCore'; product.package = package
    widget.package_product_dependencies << product
    build = project.new(Xcodeproj::Project::Object::PBXBuildFile); build.product_ref = product
    widget.frameworks_build_phase.files << build
  end
  widget.build_configurations.each do |c|
    c.base_configuration_reference = app.build_configurations.find { |host| host.name == c.name }&.base_configuration_reference
    c.build_settings.merge!({
      'PRODUCT_BUNDLE_IDENTIFIER' => "#{bundle}.SquadPhotoWidget",
      'PRODUCT_NAME' => 'SquadPhotoWidget',
      'INFOPLIST_FILE' => "#{widget_path}/Info.plist",
      'CODE_SIGN_ENTITLEMENTS' => "#{widget_path}/SquadPhotoWidget.entitlements",
      'SQUADLY_WIDGET_APP_GROUP' => group_id, 'SQUADLY_WIDGET_URL_SCHEME' => scheme,
      'SWIFT_VERSION' => '5.0', 'APPLICATION_EXTENSION_API_ONLY' => 'YES',
      'SKIP_INSTALL' => 'YES', 'MARKETING_VERSION' => '$(FLUTTER_BUILD_NAME)', 'CURRENT_PROJECT_VERSION' => '$(FLUTTER_BUILD_NUMBER)',
      'TARGETED_DEVICE_FAMILY' => '1,2', 'IPHONEOS_DEPLOYMENT_TARGET' => '15.0',
      'GENERATE_INFOPLIST_FILE' => 'NO',
    })
  end
  app.build_configurations.each do |c|
    c.build_settings['SQUADLY_WIDGET_APP_GROUP'] = group_id
    c.build_settings['SQUADLY_WIDGET_URL_SCHEME'] = scheme
    c.build_settings['CODE_SIGN_ENTITLEMENTS'] ||= 'Runner/Runner.entitlements'
  end
  plist_path = File.join(base, 'Runner/Info.plist')
  plist = Xcodeproj::Plist.read_from_path(plist_path)
  plist['SquadlyWidgetAppGroup'] = '$(SQUADLY_WIDGET_APP_GROUP)'
  plist['SquadlyWidgetURLScheme'] = '$(SQUADLY_WIDGET_URL_SCHEME)'
  plist['UIBackgroundModes'] = ((plist['UIBackgroundModes'] || []) + ['remote-notification']).uniq
  urls = plist['CFBundleURLTypes'] || []
  urls << { 'CFBundleURLName' => "#{bundle}.photo-widget", 'CFBundleURLSchemes' => ['$(SQUADLY_WIDGET_URL_SCHEME)'] } unless urls.any? { |u| (u['CFBundleURLSchemes'] || []).include?('$(SQUADLY_WIDGET_URL_SCHEME)') }
  plist['CFBundleURLTypes'] = urls
  Xcodeproj::Plist.write_to_path(plist, plist_path)
  entitlement_path = File.join(base, 'Runner/Runner.entitlements')
  entitlements = File.exist?(entitlement_path) ? Xcodeproj::Plist.read_from_path(entitlement_path) : {}
  groups = entitlements['com.apple.security.application-groups'] || []
  groups << '$(SQUADLY_WIDGET_APP_GROUP)' unless groups.include?('$(SQUADLY_WIDGET_APP_GROUP)')
  entitlements['com.apple.security.application-groups'] = groups
  Xcodeproj::Plist.write_to_path(entitlements, entitlement_path)
  project.save
  puts "Configured photo extension and isolated group for #{relative}"
end
