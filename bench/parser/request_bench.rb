require File.expand_path('../../../lib/http_tools', __FILE__)
require 'benchmark'

request = "GET / HTTP/1.1\r\nHost: example.com\r\nUser-Agent: Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_8; en-gb) AppleWebKit/533.16 (KHTML, like Gecko) Version/5.0 Safari/533.16\r\nAccept: application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5\r\nAccept-Language: en-gb\r\nAccept-Encoding: gzip, deflate\r\nConnection: keep-alive\r\n\r\n"
repeats = 10_000

Benchmark.bm(41) do |x|
  x.report("HTTPTools::Parser") do
    repeats.times do
       HTTPTools::Parser.new << request
    end
  end
  
  x.report("HTTPTools::Parser (reset)") do
    parser = HTTPTools::Parser.new
    repeats.times do
       parser << request
       parser.reset
    end
  end
  
  x.report("HTTPTools::Parser (reset, with callbacks)") do
    parser = HTTPTools::Parser.new
    parser.on(:header) {}
    parser.on(:finish) {}
    repeats.times do
       parser << request
       parser.reset
    end
  end
  
  x.report("HTTPTools::Parser (reset, with env)") do
    parser = HTTPTools::Parser.new
    repeats.times do
       parser << request
       parser.env
       parser.reset
    end
  end
end
