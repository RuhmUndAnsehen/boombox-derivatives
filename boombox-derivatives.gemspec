# frozen_string_literal: true

require_relative 'lib/boombox/derivatives/version'

Gem::Specification.new do |spec|
  spec.name          = 'boombox-derivatives'
  spec.version       = Boombox::Derivatives::VERSION
  spec.authors       = ['RuhmUndAnsehen']
  spec.email         = ['97001540+RuhmUndAnsehen@users.noreply.github.com']

  spec.summary       = 'Financial instrument library for the Boombox software'
  # spec.description   = 'TODO: Write a longer description or delete this line.'
  spec.homepage      = 'https://github.com/RuhmUndAnsehen/boombox-derivatives'
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['allowed_push_host'] = 'TODO: Set to \'https://mygemserver.com\''

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/RuhmUndAnsehen/boombox-derivatives'
  spec.metadata['changelog_uri'] = 'https://github.com/RuhmUndAnsehen/boombox-derivatives/blob/main/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{\A(?:test|spec|features|vendor)/})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency 'example-gem', '~> 1.0'
  spec.add_dependency 'activesupport'
  spec.add_dependency 'torch-rb', '~> 0.14'

  # For more information and examples about making a new gem, checkout our
  # guide at: https://bundler.io/guides/creating_gem.html
end
