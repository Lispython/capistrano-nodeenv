# -*- encoding: utf-8 -*-
require File.expand_path('../lib/capistrano-nodeenv/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Alexandr Lispython"]
  gem.email         = ["alex@obout.ru"]
  gem.description   = %q{a capistrano recipe to deploy nodejs apps with nodenev.}
  gem.summary       = %q{a capistrano recipe to deploy nodejs apps with nodenev.}
  gem.homepage      = "https://github.com/Lispython/capistrano-nodeenv"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "capistrano-nodeenv"
  gem.require_paths = ["lib"]
  gem.version       = Capistrano::Nodeenv::VERSION

  gem.add_dependency("capistrano")
  gem.add_dependency("capistrano-file-transfer-ext", "~> 0.0.3")
end
