$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "track_changes/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "culturecode-track_changes"
  s.version     = TrackChanges::VERSION
  s.authors     = ["Nicholas Jakobsen, Ryan Wallace"]
  s.email       = ["contact@culturecode.ca"]
  s.homepage    = "https://github.com/culturecode/track_changes"
  s.summary     = "Easily track changes to various ActiveRecord models"
  s.description = "Easily track changes to various ActiveRecord models. Supports both attribute and method tracking."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 4.2.0"

  s.add_development_dependency "sqlite3"
end
