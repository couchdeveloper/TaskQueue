Pod::Spec.new do |spec|
  spec.name = 'cd.TaskQueue'
  spec.version = '0.3.0'
  spec.summary = 'A TaskQueue controls the execution of asynchronous functions.'
  spec.license = 'Apache License, Version 2.0'
  spec.homepage = 'https://github.com/couchdeveloper/TaskQueue'
  spec.authors = { 'Andreas Grosam' => 'couchdeveloper@gmail.com' }
  spec.source = { :git => 'https://github.com/couchdeveloper/TaskQueue.git', :tag => "#{spec.version}" }

  spec.osx.deployment_target = '10.10'
  spec.ios.deployment_target = '9.0'
  spec.tvos.deployment_target = '10.0'
  spec.watchos.deployment_target = '3.0'

  spec.source_files = "Sources/*.swift"

  spec.requires_arc = true
end
