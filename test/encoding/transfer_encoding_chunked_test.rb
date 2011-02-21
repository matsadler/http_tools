base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class TransferEncodingChunkedTest < Test::Unit::TestCase
  
  def test_decode_1_chunk
    encoded = "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal(["<h1>Hello world</h1>", nil], decoded)
    assert_equal("14\r\n<h1>Hello world</h1>\r\n0\r\n", encoded)
  end
  
  def test_decode_2_chunks
    encoded = "14\r\n<h1>Hello world</h1>\r\n12\r\n<p>Lorem ipsum</p>\r\n0\r\n"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal(["<h1>Hello world</h1><p>Lorem ipsum</p>", nil], decoded)
  end
  
  def test_decode_incomplete
    encoded = "14\r\n<h1>Hello world</h1>\r\n12\r\n<p>Lorem ipsum"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal(["<h1>Hello world</h1>", "12\r\n<p>Lorem ipsum"], decoded)
  end
  
  def test_decode_line_by_line
    part1 = "14\r\n"
    part2 = "<h1>Hello world</h1>\r\n"
    part3 = "12\r\n"
    part4 = "<p>Lorem ipsum</p>\r\n"
    part5 = "0\r\n"
    
    result = HTTPTools::Encoding.transfer_encoding_chunked_decode(part1)
    assert_equal([nil, "14\r\n"], result)
    decoded, remainder = result
    decoded ||= ""
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part2)
    assert_equal(["<h1>Hello world</h1>", ""], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part3)
    assert_equal([nil, "12\r\n"], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part4)
    assert_equal(["<p>Lorem ipsum</p>", ""], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part5)
    assert_equal([nil, nil], res)
    part, remainder = res
    decoded += part if part
    
    assert_equal("<h1>Hello world</h1><p>Lorem ipsum</p>", decoded)
    assert_nil(remainder)
  end
  
  def test_decode_broken_between_lines
    part1 = "14\r\n<h1>Hello"
    part2 = " world</h1>\r\nf"
    part3 = "\r\n<p>Lorem ipsum "
    part4 = "\r\n12\r\n"
    part5 = "dolor sit amet</p"
    part6 = ">\r\n0\r\n"
    
    result = HTTPTools::Encoding.transfer_encoding_chunked_decode(part1)
    assert_equal([nil, "14\r\n<h1>Hello"], result)
    decoded, remainder = result
    decoded ||= ""
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part2)
    assert_equal(["<h1>Hello world</h1>", "f"], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part3)
    assert_equal([nil, "f\r\n<p>Lorem ipsum "], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part4)
    assert_equal(["<p>Lorem ipsum ", "12\r\n"], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part5)
    assert_equal([nil, "12\r\ndolor sit amet</p"], res)
    part, remainder = res
    decoded += part if part
    
    res = HTTPTools::Encoding.transfer_encoding_chunked_decode(remainder+part6)
    assert_equal(["dolor sit amet</p>", nil], res)
    part, remainder = res
    decoded += part if part
    
    expected = "<h1>Hello world</h1><p>Lorem ipsum dolor sit amet</p>"
    assert_equal(expected, decoded)
    assert_nil(remainder)
  end
  
  def test_decode_with_empty_line
    encode="16\r\n<h1>Hello world</h1>\r\n\r\n12\r\n<p>Lorem ipsum</p>\r\n0\r\n"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encode)
    
    assert_equal(["<h1>Hello world</h1>\r\n<p>Lorem ipsum</p>", nil], decoded)
  end
  
  def test_decode_doesnt_mangle_input
    encoded = "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal("14\r\n<h1>Hello world</h1>\r\n0\r\n", encoded)
  end
  
  def test_decode_with_space_after_chunk_length
    # some servers mistakenly put a space after the chunk length
    encoded = "14  \r\n<h1>Hello world</h1>\r\n0\r\n"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal(["<h1>Hello world</h1>", nil], decoded)
  end
  
  def test_decode_lots_of_tiny_chunks
    encoded = "1\r\na\r\n" * 10000 + "0\r\n"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal(["a" * 10000, nil], decoded)
  end
  
  def test_decode_break_between_cr_lf
    encoded = "14\r\n<h1>Hello world</h1>\r"
    decoded = HTTPTools::Encoding.transfer_encoding_chunked_decode(encoded)
    
    assert_equal([nil, "14\r\n<h1>Hello world</h1>\r"], decoded)
  end
  
  def test_encode
    encoded = HTTPTools::Encoding.transfer_encoding_chunked_encode("foo")
    
    assert_equal("3\r\nfoo\r\n", encoded)
  end
  
  def test_encode_empty_string
    encoded = HTTPTools::Encoding.transfer_encoding_chunked_encode("")
    
    assert_equal("0\r\n", encoded)
  end
  
  
  def test_encode_nil
    encoded = HTTPTools::Encoding.transfer_encoding_chunked_encode(nil)
    
    assert_equal("0\r\n", encoded)
  end
  
end