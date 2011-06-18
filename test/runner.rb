puts
if defined? RUBY_DESCRIPTION
  puts RUBY_DESCRIPTION
elsif defined? RUBY_ENGINE
  puts "#{RUBY_ENGINE} #{RUBY_VERSION} (#{RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"
else
  puts "ruby #{RUBY_VERSION} (#{RELEASE_DATE} patchlevel #{RUBY_PATCHLEVEL}) [#{RUBY_PLATFORM}]"
end

Dir["**/*_test.rb"].each {|test| require File.expand_path(test)}
