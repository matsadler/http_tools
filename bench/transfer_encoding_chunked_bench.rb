require File.expand_path('../../lib/http_tools', __FILE__)
require 'benchmark'

repeats = 1_000

Benchmark.bm(36) do |x|
  encoded = "1\r\na\r\n" * 100 + "0\r\n"
  x.report("lots of very short chunks") do
    repeats.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  encoded = "16\r\n<h1>Hello world</h1>\r\n\r\n12\r\n<p>Lorem ipsum</p>\r\n" * 50 + "0\r\n"
  x.report("slightly less slightly longer chunks") do
    repeats.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
  
  encoded = "2710\r\n#{"a" * 10000}\r\n" * 2 + "0\r\n"
  x.report("a couple of big chunks") do
    repeats.times do
       HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    end
  end
end
