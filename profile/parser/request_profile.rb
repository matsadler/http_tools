base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'rubygems'
require 'ruby-prof'

request = "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_8; en-gb) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nAccept-Language: en-gb\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\n\r\n"
parser = HTTPTools::Parser.new

result = RubyProf.profile do
  parser << request
end
RubyProf::FlatPrinter.new(result).print(STDOUT, 0)