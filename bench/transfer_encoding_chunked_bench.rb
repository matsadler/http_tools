base = File.expand_path(File.dirname(__FILE__) + '/../lib')
require base + '/http_tools'
require 'benchmark'

Benchmark.bm(36) do |x|
  encoded = "1\r\na\r\n" * 100 + "0\r\n"
  x.report("lots of very short chunks") do
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  encoded = "16\r\n<h1>Hello world</h1>\r\n\r\n12\r\n<p>Lorem ipsum</p>\r\n" * 50 + "0\r\n"
  x.report("slightly less slightly longer chunks") do
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  encoded = "2710\r\n#{"a" * 10000}\r\n" * 2 + "0\r\n"
  x.report("a couple of big chunks") do
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
end
