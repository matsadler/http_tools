base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'benchmark'

response = "HTTP/1.1 200 OK\r\nServer: Apache/2.2.3 (CentOS)\r\nLast-Modified: Thu, 03 Jun 2010 17:40:12 GMT\r\nETag: \"4d2c-23e-48823b2cf3700\"\r\nAccept-Ranges: bytes\r\nContent-Type: text/html; charset=UTF-8\r\nConnection: Keep-Alive\r\nDate: Wed, 21 Jul 2010 16:26:04 GMT\r\nAge: 7985   \r\nContent-Length: 574\r\n\r\n<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\r\n<HTML>\r\n<HEAD>\r\n  <META http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\r\n  <TITLE>Example Web Page</TITLE>\r\n</HEAD> \r\n<body>  \r\n<p>You have reached this web page by typing &quot;example.com&quot;,\r\n&quot;example.net&quot;,\r\n  or &quot;example.org&quot; into your web browser.</p>\r\n<p>These domain names are reserved for use in documentation and are not available \r\n  for registration. See <a href=\"http://www.rfc-editor.org/rfc/rfc2606.txt\">RFC \r\n  2606</a>, Section 3.</p>\r\n</BODY>\r\n</HTML>\r\n\r\n"

Benchmark.bm(25) do |x|
  x.report("HTTPTools::Parser") do
    10_000.times do
       HTTPTools::Parser.new << response
    end
  end
  
  x.report("HTTPTools::Parser (reset)") do
    parser = HTTPTools::Parser.new
    10_000.times do
       parser << response
       parser.reset
    end
  end
  
  begin
    require 'rubygems'
    require 'http/parser'
    x.report("Http::Parser") do
      10_000.times do
        parser = Http::Parser.new
        parser << response
      end
    end
  rescue LoadError
  end
end