base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class ResponseTest < Test::Unit::TestCase
  
  def test_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:version) {|v| version = v}
    
    parser << "HTTP/1.1 "
    
    assert_equal("1.1", version)
  end
  
  def test_ok
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    
    parser << "HTTP/1.1 200 OK\r\n\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_not_found
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    
    parser << "HTTP/1.1 404 Not Found\r\n\r\n"
    
    assert_equal(404, code)
    assert_equal("Not Found", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_no_content
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    
    parser << "HTTP/1.1 204 No Content\r\n\r\n"
    
    assert_equal(204, code)
    assert_equal("No Content", message)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_not_modified
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    
    parser << "HTTP/1.1 304 Not Modified\r\n\r\n"
    
    assert_equal(304, code)
    assert_equal("Not Modified", message)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_force_no_body
    parser = HTTPTools::Parser.new
    parser.force_no_body = true
    headers = nil
    
    parser.add_listener(:headers) {|h| headers = h}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "\r\n"
    
    assert_equal({"Content-Length" => "20"}, headers)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_apple_dot_com
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Server: Apache/2.2.11 (Unix)\r\n"
    parser << "Content-Type: text/html; charset=utf-8\r\n"
    parser << "Cache-Control: max-age=319\r\n"
    parser << "Expires: Sun, 16 May 2010 18:15:18 GMT\r\n"
    parser << "Date: Sun, 16 May 2010 18:09:59 GMT\r\n"
    parser << "Connection: keep-alive\r\n"
    parser << "\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({
      "Server" => "Apache/2.2.11 (Unix)",
      "Content-Type" => "text/html; charset=utf-8",
      "Cache-Control" => "max-age=319",
      "Expires" => "Sun, 16 May 2010 18:15:18 GMT",
      "Date" => "Sun, 16 May 2010 18:09:59 GMT",
      "Connection" => "keep-alive"}, headers)
  end
  
  def test_stream
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = []
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:stream) {|b| body << b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "\r\n"
    parser << "<h1>Hello"
    parser << " world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20"}, headers)
    assert_equal(["<h1>Hello", " world</h1>"], body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_body
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:body) {|b| body = b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "\r\n"
    parser << "<h1>Hello"
    parser << " world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_sub_line_chunks
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:body) {|b| body = b}
    
    parser << "HTTP/"
    parser << "1."
    parser << "1 "
    parser << "200"
    parser << " OK\r\n"
    parser << "Content-"
    parser << "Length: 20\r\n\r\n"
    parser << "<h1>Hello"
    parser << " world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_body_with_key_terminator_like_value
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:body) {|b| body = b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 21\r\n"
    parser << "\r\n<h1>Hello: world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "21"}, headers)
    assert_equal("<h1>Hello: world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_lazy_server
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:body) {|b| body = b}
    
    parser << "HTTP/1.1 200 OK\n"
    parser << "Content-Type: text/html; charset=utf-8\n"
    parser << "Connection: close\n\n"
    parser << "<h1>hello world</h1>"
    parser.finish # notify parser the connection has closed
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Type" => "text/html; charset=utf-8", "Connection" => "close"}, headers)
    assert_equal("<h1>hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_chunked
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:body) {|b| body = b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "\r\n"
    parser << "14\r\n"
    parser << "<h1>Hello world</h1>\r\n"
    parser << "0\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Transfer-Encoding" => "chunked"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_chunked_stream
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = []
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:stream) {|b| body << b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "\r\n"
    parser << "9\r\n<h1>Hello\r\n"
    parser << "b\r\n world</h1>\r\n"
    parser << "0\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Transfer-Encoding" => "chunked"}, headers)
    assert_equal(["<h1>Hello", " world</h1>"], body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_chunked_stream_with_multiple_chunks_at_once
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = []
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:headers) {|h| headers = h}
    parser.add_listener(:stream) {|b| body << b}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "\r\n"
    parser << "9\r\n<h1>Hello\r\nb\r\n world</h1>\r\n"
    parser << "12\r\n<p>Lorem ipsum</p>\r\n"
    parser << "0\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Transfer-Encoding" => "chunked"}, headers)
    assert_equal(["<h1>Hello world</h1>", "<p>Lorem ipsum</p>"], body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_finished
    parser = HTTPTools::Parser.new
    code, message, body, remainder = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:body) {|b| body = b}
    parser.add_listener(:finished) {|r| remainder = r}
    
    parser << "HTTP/1.1 200 OK\r\nContent-Length: 20\r\n\r\n"
    parser << "<h1>Hello world</h1>HTTP/1.1 404 Not Found\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal("<h1>Hello world</h1>", body)
    assert_equal("HTTP/1.1 404 Not Found\r\n", remainder)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_finished_chunked
    parser = HTTPTools::Parser.new
    code, message, body, remainder = nil
    
    parser.add_listener(:status) {|c, m| code, message = c, m}
    parser.add_listener(:body) {|b| body = b}
    parser.add_listener(:finished) {|r| remainder = r}
    
    parser << "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\nHTTP/1.1 404 Not Found\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal("<h1>Hello world</h1>", body)
    assert_equal("HTTP/1.1 404 Not Found\r\n", remainder)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_trailer
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {|t| trailer = t}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_trailer_sub_line_chunks
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {|t| trailer = t}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\nX-Chec"
    parser << "ksum: 2a2e12c8eda"
    parser << "d17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_force_trailer
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {|t| trailer = t}
    
    parser.force_trailer = true
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_error_on_unallowed_trailer
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_raise(HTTPTools::EndOfMessageError) do
      parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    end
  end
  
  def test_error_on_unexpected_trailer
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    assert_raise(HTTPTools::EndOfMessageError) do
      parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    end
  end
  
  def test_invalid_trailer_key
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {|t| trailer = t}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    assert_raise(HTTPTools::ParseError) do
      parser << "x-invalid key: value\r\n\r\n"
    end
  end
  
  def test_invalid_trailer_value
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {|t| trailer = t}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    assert_raise(HTTPTools::ParseError) do
      parser << "x-test: inva\0lid\r\n\r\n"
    end
  end
  
  def test_invalid_version
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "HTTP/one dot one 200 OK"}
  end
  
  def test_invalid_status
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "HTTP/1.1 0 Fail"}
  end
  
  def test_finish_early
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    
    assert_raise(HTTPTools::MessageIncompleteError) {parser.finish}
  end
  
end