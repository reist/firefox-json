lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'firefox-json/version'

Gem::Specification.new do |spec|
  spec.name          = 'firefox-json'
  spec.version       = FirefoxJson::VERSION
  spec.date          = '2018-03-20'
  spec.summary       = %q{Read and manipulate Firefox's json files.}
  spec.homepage      = 'https://github.com/reist/firefox-json'
  spec.license       = 'ISC'
  spec.author        = 'Boris Peterbarg'
  spec.email         = 'boris.sa@gmail.com'

  spec.required_ruby_version = '>= 2.3.0'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_runtime_dependency 'oj', '~> 3.5'
  spec.add_runtime_dependency 'inifile', '~> 3.0'
  spec.add_runtime_dependency 'extlz4', '~> 0.2.5'
end
