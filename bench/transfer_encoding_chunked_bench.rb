base = File.expand_path(File.dirname(__FILE__) + '/../lib')
require base + '/http_tools'
require 'benchmark'

Benchmark.bm(36) do |x|
  x.report("lots of very short chunks") do
    encoded = "1\r\na\r\n" * 100 + "0\r\n"
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  x.report("slightly less slightly longer chunks") do
    encoded = "16\r\n<h1>Hello world</h1>\r\n\r\n12\r\n<p>Lorem ipsum</p>\r\n" * 50 + "0\r\n"
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  x.report("a couple of big chunks") do
    encoded = "2710\r\n#{"a" * 1000}" * 2 + "0\r\n"
    1_000.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
end