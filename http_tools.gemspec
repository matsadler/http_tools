Gem::Specification.new do |s|
  s.name = "http_tools"
  s.version = "0.4.1"
  s.summary = "Pure Ruby HTTP parser and friends"
  s.description = "A fast-as-possible pure Ruby HTTP parser plus associated lower level utilities to aid working with HTTP and the web."
  s.files = %W{lib test bench profile example}.map {|dir| Dir["#{dir}/**/*.rb"]}.flatten << "README.rdoc"
  s.require_path = "lib"
  s.rdoc_options = ["--main", "README.rdoc", "--charset", "utf-8"]
  s.extra_rdoc_files = ["README.rdoc"]
  s.author = "Matthew Sadler"
  s.email = "mat@sourcetagsandcodes.com"
  s.homepage = "http://github.com/matsadler/http_tools"
end
