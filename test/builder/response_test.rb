base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class ResponseTest < Test::Unit::TestCase
  
  def test_status_ok
    result = HTTPTools::Builder.response(:ok)
    
    assert_equal("HTTP/1.1 200 OK\r\n\r\n", result)
  end
  
  def test_status_not_found
    result = HTTPTools::Builder.response(:not_found)
    
    assert_equal("HTTP/1.1 404 Not Found\r\n\r\n", result)
  end
  
  def test_status_with_code
    result = HTTPTools::Builder.response(500)
    
    assert_equal("HTTP/1.1 500 Internal Server Error\r\n\r\n", result)
  end
  
  def test_headers
    result = HTTPTools::Builder.response(:ok, "Content-Type" => "text/html", "Content-Length" => 1024)
    
    expected = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: 1024\r\n\r\n"
    assert_equal(expected, result)
  end
  
end