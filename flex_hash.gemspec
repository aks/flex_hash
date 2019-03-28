# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "flex_hash/version"

Gem::Specification.new do |spec|
  spec.name          = "flex_hash"
  spec.version       = FlexHash::VERSION
  spec.authors       = ["Alan Stebbens"]
  spec.email         = ["aks@stebbens.org"]

  spec.summary       = %{a Hash subclass with auto-initialization and array indexing}
  spec.description   = '''
    The FlexHash class is a sub-class of Hash which provides for automatic initialization of
    indexed sub-hashes, and true array indexing.
  '''
  spec.homepage      = "https://github.com/aks/flex_hash"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "https://rubygems.com"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = spec.homepage
    spec.metadata["changelog_uri"] = spec.homepage + "/CHANGELOG"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "awesome_print"
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "fuubar"
  spec.add_development_dependency "gem-release"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "guard-yard"
  spec.add_development_dependency "package_cloud", ">= 0.2.20"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "rake", ">= 10.0"
  spec.add_development_dependency "redcarpet"
  spec.add_development_dependency "rspec", ">= 3.0"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "yard"

  if `uname -a` =~ /Darwin/
    spec.add_development_dependency "terminal-notifier-guard"
  end
end
