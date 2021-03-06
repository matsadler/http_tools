base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'rubygems'
require 'ruby-prof'

body = "x" * 1024 * 1024 * 1
response = "HTTP/1.1 200 OK\r\nDate: Mon, 06 Jun 2011 14:55:51 GMT\r\nServer: Apache/2.2.17 (Unix) mod_ssl/2.2.17 OpenSSL/0.9.8l DAV/2 mod_fastcgi/2.4.2\r\nLast-Modified: Mon, 06 Jun 2011 14:55:49 GMT\r\nETag: \"3f18045-400-4a50c4c87c740\"\r\nAccept-Ranges: bytes\r\nContent-Length: #{body.length}\r\nContent-Type: text/plain\r\n\r\n"
chunks = []
64.times {|i| chunks << body[i * 64, body.length / 64]}
parser = HTTPTools::Parser.new

result = RubyProf.profile do
  parser << response
  chunks.each {|chunk| parser << chunk}
end
RubyProf::FlatPrinter.new(result).print(STDOUT, 0)