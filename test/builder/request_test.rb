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
    result = HTTPTools::Builder.request(:get, "www.foobar.com", "/", "x-test" => "foo")
    
    assert_equal("GET / HTTP/1.1\r\nHost: www.foobar.com\r\nx-test: foo\r\n\r\n", result)
  end
  
end