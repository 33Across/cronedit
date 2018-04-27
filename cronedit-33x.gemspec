# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "cronedit-33x"
  spec.version       = "1.0.0"
  spec.authors       = ["33Across", "Viktor Zigo"]
  spec.email         = ["viz@alephzarro.com"]
  spec.summary       = %q{CronEdit is a Ruby editor library for crontab.}
  spec.description   = %q{33Across fork of http://cronedit.rubyforge.org/}
  spec.homepage      = "https://github.com/33Across/cronedit"

  spec.files       = Dir["lib/**/*.rb"] + Dir["test/**/*"]

  spec.required_ruby_version = '>= 1.9.3'
end
