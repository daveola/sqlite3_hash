# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sqlite3_hash/version'

Gem::Specification.new do |spec|
  spec.name          = "sqlite3_hash"
  spec.version       = Sqlite3Hash::VERSION
  spec.authors       = ["David Ljung Madison Stellar"]
  spec.email         = ["http://Contact.MarginalHacks.com/"]

  spec.summary       = %q{A persistent simple Hash backed by sqlite3}
  spec.description   = "A persistent simple Hash backed by sqlite3.\n\nContains (almost) the same features/API as the Ruby 2.0.0 Hash object"
  spec.homepage      = "http://MarginalHacks.com/"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    #spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  #spec.add_development_dependency "true", "~> "
  spec.add_development_dependency "rspec"
  spec.add_dependency "sqlite3"
end
