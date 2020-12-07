Pod::Spec.new do |spec|
  spec.name = 'cdTaskQueue'
  spec.version = '0.13.0'
  spec.summary = 'A TaskQueue controls the execution of asynchronous functions.'
  spec.license = 'Apache License, Version 2.0'
  spec.homepage = 'https://github.com/couchdeveloper/TaskQueue'
  spec.authors = { 'Andreas Grosam' => 'couchdeveloper@gmail.com' }
  spec.source = { :git => 'https://github.com/couchdeveloper/TaskQueue.git', :tag => "#{spec.version}" }

  spec.osx.deployment_target = '10.12'
  spec.ios.deployment_target = '10.10'
  spec.tvos.deployment_target = '10.2'
  spec.watchos.deployment_target = '3.2'

  spec.module_name = 'TaskQueue'
  spec.source_files = "Sources/*.swift"

  spec.requires_arc = true

  spec.swift_version = ['4.2', '5']
end
