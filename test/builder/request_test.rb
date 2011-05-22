base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'
require 'uri'

class RequestTest < Test::Unit::TestCase
  
  def test_get
    result = HTTPTools::Builder.request(:get, "www.example.com", "/test")
    
    assert_equal("GET /test HTTP/1.1\r\nHost: www.example.com\r\n\r\n", result)
  end
  
  def test_post
    result = HTTPTools::Builder.request(:post, "www.test.com", "/example")
    
    assert_equal("POST /example HTTP/1.1\r\nHost: www.test.com\r\n\r\n", result)
  end
  
  def test_headers
    result = HTTPTools::Builder.request(:get, "www.foobar.com", "/", "X-Test" => "foo")
    
    assert_equal("GET / HTTP/1.1\r\nHost: www.foobar.com\r\nX-Test: foo\r\n\r\n", result)
  end
  
  def test_newline_separated_multi_value_headers
    result = HTTPTools::Builder.request(:get, "www.foo.com", "/", "X-Test" => "foo\nbar")
    
    assert_equal("GET / HTTP/1.1\r\nHost: www.foo.com\r\nX-Test: foo\r\nX-Test: bar\r\n\r\n", result)
  end
  
  def test_array_multi_value_headers
    result = HTTPTools::Builder.request(:get, "www.foo.com", "/", "X-Test" => ["foo", "bar"])
    
    assert_equal("GET / HTTP/1.1\r\nHost: www.foo.com\r\nX-Test: foo\r\nX-Test: bar\r\n\r\n", result)
  end
  
  def test_non_string_headers
    result = HTTPTools::Builder.request(:get, "www.foobar.com", "/", "X-Test" => 42)
    
    assert_equal("GET / HTTP/1.1\r\nHost: www.foobar.com\r\nX-Test: 42\r\n\r\n", result)
  end
  
end