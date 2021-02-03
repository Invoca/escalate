# frozen_string_literal: true

require_relative "lib/escalate/version"

Gem::Specification.new do |spec|
  spec.name          = "escalate"
  spec.version       = Escalate::VERSION
  spec.authors       = ["Invoca Development", "Octothorp"]
  spec.email         = ["development@invoca.com", "octothorp@invoca.com"]

  spec.summary       = "A simple and lightweight gem to escalate rescued exceptions."
  spec.description   = "A simple and lightweight gem to escalate rescued exceptions."
  spec.homepage      = "https://github.com/invoca/escalate"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "homepage_uri"      => spec.homepage,
    "changelog_uri"     => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport"
end
