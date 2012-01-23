# encoding: ASCII-8BIT
base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class ParserResponseTest < Test::Unit::TestCase
  
  def test_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "HTTP/1.1 200 OK\r\n\r\n"
    
    assert_equal("HTTP/1.1", version)
  end
  
  def test_one_dot_x_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "HTTP/1.x 200 OK\r\n\r\n"
    
    assert_equal("HTTP/1.x", version)
  end
  
  def test_ok
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 200 OK\r\n\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_not_found
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 404 Not Found\r\n\r\n"
    
    assert_equal(404, code)
    assert_equal("Not Found", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_missing_message
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 302\r\n\r\n"
    
    assert_equal(302, code)
    assert_equal("", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_non_standard_message
    parser = HTTPTools::Parser.new
    version, code, message = nil
    
    parser.add_listener(:header) do
      version = parser.version
      code = parser.status_code
      message = parser.message
    end
    
    parser << "HTTP/1.0 200 (OK)\r\n\r\n"
    
    assert_equal("HTTP/1.0", version)
    assert_equal(200, code)
    assert_equal("(OK)", message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_status_message_with_accent
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 403 Acc\xC3\xA8s interdit\r\n\r\n"
    
    assert_equal(403, code)
    expected_message = "Acc\xC3\xA8s interdit"
    if expected_message.respond_to?(:force_encoding)
      expected_message.force_encoding(message.encoding)
    end
    assert_equal(expected_message, message)
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_no_content
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 204 No Content\r\n\r\n"
    
    assert_equal(204, code)
    assert_equal("No Content", message)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_not_modified
    parser = HTTPTools::Parser.new
    code, message = nil
    
    parser.add_listener(:header) do
      code, message = parser.status_code, parser.message
    end
    
    parser << "HTTP/1.1 304 Not Modified\r\n\r\n"
    
    assert_equal(304, code)
    assert_equal("Not Modified", message)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_force_no_body
    parser = HTTPTools::Parser.new
    parser.force_no_body = true
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "\r\n"
    
    assert_equal({"Content-Length" => "20"}, headers)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_messed_up_iis_headers
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Server:: Harris Associates L.P.\r\n"
    parser << "X-DIP:202\r\n"
    parser << "\r\n"
    
    assert_equal({
      "Server" => ": Harris Associates L.P.",
      "X-DIP" => "202"}, headers)
  end
  
  def test_space_in_header_key
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "X-Powered-By: PHP/5.3.5\r\n"
    parser << "HTTP Status Code: HTTP/1.1 404 Not Found\r\n"
    parser << "\r\n"
    
    assert_equal({
      "X-Powered-By" => "PHP/5.3.5",
      "HTTP Status Code" => "HTTP/1.1 404 Not Found"}, headers)
  end
  
  def test_header_empty_value
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "X-Empty: \r\n"
    parser << "Content-Type: text/html\r\n\r\n"
    
    assert_equal({
      "X-Empty" => "",
      "Content-Type" => "text/html"}, headers)
  end
  
  def test_weird_iis_content_header
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "Content:\r\n"
    parser << "\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20", "Content" => ""}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_multiple_set_cookie_headers
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Set-Cookie: foo=bar\r\n"
    parser << "Set-Cookie: baz=qux\r\n\r\n"
    
    assert_equal({"Set-Cookie" => "foo=bar\nbaz=qux"}, headers)
  end
  
  def test_multi_line_header_value
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type: text/html;\r\n"
    parser << " charset=utf-8\r\n\r\n"
    
    assert_equal({"Content-Type" => "text/html; charset=utf-8"}, headers)
  end
  
  def test_multi_line_header_value_in_one_chunk
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type: text/html;\r\n charset=utf-8\r\n\r\n"
    
    assert_equal({"Content-Type" => "text/html; charset=utf-8"}, headers)
  end
  
  def test_multi_line_header_value_sub_line_chunks
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type:"
    parser << " text/"
    parser << "html;\r\n "
    parser << "charset="
    parser << "utf-8\r\n\r\n"
    
    assert_equal({"Content-Type" => "text/html; charset=utf-8"}, headers)
  end
  
  def test_header_value_separated_by_newline
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type:\r\n"
    parser << "\t     text/html;\r\n"
    parser << "\t     charset=utf-8\r\n\r\n"
    
    assert_equal({"Content-Type" => "text/html; charset=utf-8"}, headers)
  end
  
  def test_multi_line_header_invalid_value
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type: text/html;\r\n"
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << " charset=\0\r\n\r\n"
    end
    
    return unless "".respond_to?(:lines)
    null = "\000".dump.gsub(/"/, "")
    assert_equal(<<-MESSAGE.chomp, error.message)
Illegal character in field body at line 3, char 10

 charset=#{null}\\r\\n
            ^
    MESSAGE
  end
  
  def test_header_value_leading_and_trailing_whitespace_is_stripped
    parser = HTTPTools::Parser.new
    headers = nil
    
    parser.add_listener(:header) {headers = parser.header}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Type:\t text/html \t\r\n\r\n"
    
    assert_equal({"Content-Type" => "text/html"}, headers)
  end
  
  def test_skip_junk_headers_at_end
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 301 Redirect\r\n"
    parser << "Location: /index.html\r\n"
    parser << "Content-Length: 74\r\n"
    parser << "301 Moved Permanently\r\n\r\n"
    parser << "You should have been redirected to\n"
    parser << "<a href=\"/index.html\">/index.html</a>.\n"
    
    assert_equal(301, code)
    assert_equal("Redirect", message)
    assert_equal({"Location" => "/index.html", "Content-Length" => "74"}, headers)
    assert_equal("You should have been redirected to\n<a href=\"/index.html\">/index.html</a>.\n", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_skip_junk_headers_at_start
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.0 200 OK\r\n"
    parser << "QWEBS/1.0 (HP 3000)\r\n"
    parser << "Content-Type: text/html\r\n\r\n"
    parser << "<h1>Hello world</h1>"
    parser.finish
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Type" => "text/html"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_skip_junk_headers_in_the_middle
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "random\t"
    parser << "garbage\n"
    parser << "Content-Type: text/html\r\n"
    parser << "\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20", "Content-Type" => "text/html"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_invalid_header_key_with_control_character
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "HTTP/1.0 200 OK\r\nx-invalid\0key: valid key\r\n"
    end
    
    return unless "".respond_to?(:lines)
    null = "\000".dump.gsub(/"/, "")
    assert_equal(<<-MESSAGE.chomp, error.message)
Illegal character in field name at line 2, char 10

x-invalid#{null}key: valid key\\r\\n
            ^
    MESSAGE
  end
  
  def test_apple_dot_com
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    
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
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
  
  def test_case_insensitive_content_length
    parser = HTTPTools::Parser.new
    headers, body = nil, ""
    
    parser.add_listener(:header) {headers = parser.header}
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "content-length: 20\r\n\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_equal({"content-length" => "20"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_zero_length_body
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    stream = []
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk; stream.push(chunk)}
    
    parser << "HTTP/1.1 302 Moved Temporarily\r\n"
    parser << "Location: http://www.example.com/\r\n"
    parser << "Content-Length: 0\r\n\r\n"
    
    assert_equal(302, code)
    assert_equal("Moved Temporarily", message)
    assert_equal({"Location" => "http://www.example.com/", "Content-Length" => "0"}, headers)
    assert_equal([""], stream)
    assert_equal("", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_zero_length_body_terminated_by_close
    parser = HTTPTools::Parser.new
    code, message, headers, body = nil
    stream = []
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk; stream.push(chunk)}
    
    parser << "HTTP/1.1 302 Moved Temporarily\r\n"
    parser << "Location: http://www.example.com/\r\n\r\n"
    parser.finish # notify parser the connection has closed
    
    assert_equal(302, code)
    assert_equal("Moved Temporarily", message)
    assert_equal({"Location" => "http://www.example.com/"}, headers)
    assert_equal([""], stream)
    assert_equal("", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_sub_line_chunks
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
  
  def test_break_between_crlf
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r"
    parser << "\nContent-Length: 20\r"
    parser << "\n\r"
    parser << "\n<h1>Hello world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Content-Length" => "20"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_double_cr
    parser = HTTPTools::Parser.new
    headers = nil
    body = ""
    
    parser.add_listener(:header) {headers = parser.header}
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Page-Completion-Status: Normal\r\r\n"
    parser << "Content-Length: 20\r\n"
    parser << "\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_equal({"Page-Completion-Status" => "Normal", "Content-Length" => "20"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_body_with_key_terminator_like_value
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
  
  def test_body_with_no_headers
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n\r\n"
    parser << "<h1>hello world</h1>"
    parser.finish # notify parser the connection has closed
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({}, headers)
    assert_equal("<h1>hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_chunked
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
  
  def test_case_insensitive_chunked
    parser = HTTPTools::Parser.new
    headers, body = nil, ""
    
    parser.add_listener(:header) do
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "transfer-encoding: CHUNKED\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    assert_equal({"transfer-encoding" => "CHUNKED"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_chunked_stream
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = []
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
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
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "\r\n"
    parser << "9\r\n<h1>Hello\r\nb\r\n world</h1>\r\n"
    parser << "12\r\n<p>Lorem ipsum</p>"
    parser << "\r\n0\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({"Transfer-Encoding" => "chunked"}, headers)
    assert_equal(["<h1>Hello", " world</h1>", "<p>Lorem ipsum</p>"], body)
    assert(parser.finished?, "parser should be finished")
  end
  
  # shouldn't really be allowed, but IIS can't do chunked encoding properly
  def test_chunked_terminated_by_close
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    body = []
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Connection: close\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "\r\n"
    parser << "9\r\n<h1>Hello\r\n"
    parser << "b\r\n world</h1>\r\n"
    parser.finish # notify parser the connection has closed
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal({
      "Transfer-Encoding" => "chunked",
      "Connection" => "close"}, headers)
    assert_equal(["<h1>Hello", " world</h1>"], body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_case_insensitive_chunked_terminated_by_close
    parser = HTTPTools::Parser.new
    headers, body = nil, ""
    
    parser.add_listener(:header) {headers = parser.header}
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "connection: CLOSE\r\n"
    parser << "Transfer-Encoding: chunked\r\n\r\n"
    parser << "9\r\n<h1>Hello\r\nb\r\n world</h1>\r\n"
    parser.finish # notify parser the connection has closed
    
    assert_equal({
      "Transfer-Encoding" => "chunked",
      "connection" => "CLOSE"}, headers)
    assert_equal("<h1>Hello world</h1>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_max_chunk_size
    parser = HTTPTools::Parser.new
    parser.max_chunk_size = 1024
    
    parser << "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
    
    assert_nothing_raised(HTTPTools::ParseError) {parser << "1\r\na\r\n"}
    assert_nothing_raised(HTTPTools::ParseError) do
      parser << "400\r\n#{"a" * 1024}\r\n"
    end
    
    assert_raise(HTTPTools::ParseError) {parser << "401\r\n"}
  end
  
  def test_upgrade_websocket_hixie_76
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    
    parser << "HTTP/1.1 101 WebSocket Protocol Handshake\r\n"
    parser << "Upgrade: WebSocket\r\n"
    parser << "Connection: Upgrade\r\n"
    parser << "Sec-WebSocket-Origin: http://example.com\r\n"
    parser << "Sec-WebSocket-Location: ws://example.com/demo\r\n"
    parser << "Sec-WebSocket-Protocol: sample\r\n\r\n8jKS'y:G*Co,Wxa-"
    
    assert_equal(101, code)
    assert_equal("WebSocket Protocol Handshake", message)
    assert_equal({
      "Upgrade" => "WebSocket",
      "Connection" => "Upgrade",
      "Sec-WebSocket-Origin" => "http://example.com",
      "Sec-WebSocket-Location" => "ws://example.com/demo",
      "Sec-WebSocket-Protocol" => "sample"}, headers)
    assert(parser.finished?, "Parser should be finished.")
    assert_equal(parser.rest, "8jKS'y:G*Co,Wxa-")
  end
  
  def test_upgrade_websocket_hybi_09
    parser = HTTPTools::Parser.new
    code, message, headers = nil
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    
    parser << "HTTP/1.1 101 Switching Protocols\r\n"
    parser << "Upgrade: websocket\r\n"
    parser << "Connection: Upgrade\r\n"
    parser << "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=\r\n"
    parser << "Sec-WebSocket-Protocol: chat\r\n\r\n"
    
    assert_equal(101, code)
    assert_equal("Switching Protocols", message)
    assert_equal({
      "Upgrade" => "websocket",
      "Connection" => "Upgrade",
      "Sec-WebSocket-Accept" => "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=",
      "Sec-WebSocket-Protocol" => "chat"}, headers)
    assert(parser.finished?, "Parser should be finished.")
    assert_equal(parser.rest, "")
  end
  
  def test_html_body_only_not_allowed
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "<html><p>HTTP is hard</p></html>"
    end
    
    return unless "".respond_to?(:lines)
    assert_equal(<<-MESSAGE.chomp, error.message)
Protocol or method not recognised at line 1, char 1

<html><p>HTTP is hard</p></html>
^
    MESSAGE
  end
  
  def test_html_body_only_allowed
    parser = HTTPTools::Parser.new
    version, code, message, headers = nil
    body = ""
    
    parser.allow_html_without_header = true
    
    parser.add_listener(:header) do
      version = parser.version
      code = parser.status_code
      message = parser.message
      headers = parser.header
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "<html><p>HTTP is hard</p></html>"
    parser.finish
    
    assert_equal("0.0", version)
    assert_equal(200, code)
    assert_equal("", message)
    assert_equal({}, headers)
    assert_equal("<html><p>HTTP is hard</p></html>", body)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_default_stream_listener
    parser = HTTPTools::Parser.new
    body = nil
    
    parser.add_listener(:finish) do
      body = parser.body
    end
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n\r\n"
    parser << "<h1>Hello"
    parser << " world</h1>"
    
    assert_equal("<h1>Hello world</h1>", body)
  end
  
  def test_overide_default_stream_listener
    parser = HTTPTools::Parser.new
    body = ""
    
    parser.add_listener(:stream) {|chunk| body << chunk}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Content-Length: 20\r\n\r\n"
    parser << "<h1>Hello"
    parser << " world</h1>"
    
    assert_equal("<h1>Hello world</h1>", body)
    assert_nil(parser.body)
  end
  
  def test_header_query
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    assert(!parser.header?, "Header not yet done.")
    
    parser << "Content-Length: 20\r\n"
    assert(!parser.header?, "Header not yet done.")
    
    parser << "\r\n"
    
    assert(parser.header?, "Header should be done.")
  end
  
  def test_finished
    parser = HTTPTools::Parser.new
    code, message, remainder = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    parser.add_listener(:finish) {remainder = parser.rest}
    
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
    code, message, remainder = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    parser.add_listener(:finish) {remainder = parser.rest}
    
    parser << "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\nHTTP/1.1 404 Not Found\r\n"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal("<h1>Hello world</h1>", body)
    assert_equal("HTTP/1.1 404 Not Found\r\n", remainder)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_finshed_without_rest
    parser = HTTPTools::Parser.new
    code, message, remainder = nil
    body = ""
    
    parser.add_listener(:header) do
      code = parser.status_code
      message = parser.message
    end
    parser.add_listener(:stream) {|chunk| body << chunk}
    parser.add_listener(:finish) {remainder = parser.rest}
    
    parser << "HTTP/1.1 200 OK\r\nContent-Length: 20\r\n\r\n"
    parser << "<h1>Hello world</h1>"
    
    assert_equal(200, code)
    assert_equal("OK", message)
    assert_equal("<h1>Hello world</h1>", body)
    assert_equal("", remainder)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_trailer
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_case_insensitive_trailer
    parser = HTTPTools::Parser.new
    headers, trailer = nil
    
    parser.add_listener(:header) {headers = parser.header}
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\ntrailer: x-checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"Transfer-Encoding" => "chunked", "trailer" => "x-checksum"}, headers)
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_trailer_sub_line_chunks
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
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
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser.force_trailer = true
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Checksum: 2a2e12c8edad17de62354ea4531ac82c\r\n\r\n"
    
    assert_equal({"X-Checksum" => "2a2e12c8edad17de62354ea4531ac82c"}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_multiple_trailer_values
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test: 1\r\n"
    parser << "X-Test: 2\r\n\r\n"
    
    assert_equal({"X-Test" => "1\n2"}, trailer)
  end
  
  def test_multi_line_trailer_value
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test: one\r\n"
    parser << " two\r\n\r\n"
    
    assert_equal({"X-Test" => "one two"}, trailer)
  end
  
  def test_multi_line_trailer_value_in_one_chunk
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test: one\r\n two\r\n\r\n"
    
    assert_equal({"X-Test" => "one two"}, trailer)
  end
  
  def test_multi_line_trailer_value_sub_line_chunks
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test:"
    parser << " on"
    parser << "e\r\n "
    parser << "t"
    parser << "wo\r\n\r\n"
    
    assert_equal({"X-Test" => "one two"}, trailer)
  end
  
  def test_trailer_value_separated_by_newline
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test:\r\n"
    parser << "\t     one\r\n"
    parser << "\t     two\r\n\r\n"
    
    assert_equal({"X-Test" => "one two"}, trailer)
  end
  
  def test_multi_line_trailer_invalid_value
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test: one\r\n"
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << " \0two\r\n"
    end
    
    return unless "".respond_to?(:lines)
    null = "\000".dump.gsub(/"/, "")
    assert_equal(<<-MESSAGE.chomp, error.message)
Illegal character in field body at line 9, char 2

 #{null}two\\r\\n
    ^
    MESSAGE
  end
  
  def test_trailer_value_leading_and_trailing_whitespace_is_stripped
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Test\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-Test:\t one \t\r\n\r\n"
    
    assert_equal({"X-Test" => "one"}, trailer)
  end
  
  def test_messed_up_iis_header_style_trailer_1
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Server: Microsoft-IIS/6.0\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: Server::\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "Server:: Harris Associates L.P.\r\n"
    parser << "\r\n"
    
    assert_equal({"Server" => ": Harris Associates L.P."}, trailer)
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_messed_up_iis_header_style_trailer_2
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: Server::\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    parser << "X-DIP:202\r\n"
    parser << "\r\n"
    
    assert_equal({"X-DIP" => "202"}, trailer)
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
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "x-invalid\0key: value\r\n\r\n"
    end
    
    return unless "".respond_to?(:lines)
    null = "\000".dump.gsub(/"/, "")
    assert_equal(<<-MESSAGE.chomp, error.message)
Illegal character in field name at line 8, char 10

x-invalid#{null}key: value\\r\\n
            ^
    MESSAGE
  end
  
  def test_invalid_trailer_value
    parser = HTTPTools::Parser.new
    trailer = nil
    
    parser.add_listener(:trailer) {trailer = parser.trailer}
    
    parser << "HTTP/1.1 200 OK\r\n"
    parser << "Transfer-Encoding: chunked\r\nTrailer: X-Checksum\r\n\r\n"
    parser << "14\r\n<h1>Hello world</h1>\r\n0\r\n"
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "x-test: inva\0lid\r\n\r\n"
    end
    
    return unless "".respond_to?(:lines)
    null = "\000".dump.gsub(/"/, "")
    assert_equal(<<-MESSAGE.chomp, error.message)
Illegal character in field body at line 8, char 13

x-test: inva#{null}lid\\r\\n
               ^
    MESSAGE
  end
  
  def test_invalid_protocol
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "HTTZ/1.1 200 OX\r\n"
    end
    
    return unless "".respond_to?(:lines)
    assert_equal(<<-MESSAGE.chomp, error.message)
Protocol or method not recognised at line 1, char 4

HTTZ/1.1 200 OX\\r\\n
   ^
    MESSAGE
  end
  
  
  def test_invalid_version
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "HTTP/one dot one 200 OK"
    end
    
    return unless "".respond_to?(:lines)
    assert_equal(<<-MESSAGE.chomp, error.message)
Invalid version specifier at line 1, char 6

HTTP/one dot one 200 OK
     ^
    MESSAGE
  end
  
  def test_invalid_status
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) {parser << "HTTP/1.1 0 Fail"}
    
    return unless "".respond_to?(:lines)
    assert_equal(<<-MESSAGE.chomp, error.message)
Invalid status line at line 1, char 11

HTTP/1.1 0 Fail
          ^
    MESSAGE
  end
  
  def test_finish_early
    parser = HTTPTools::Parser.new
    
    parser << "HTTP/1.1 200 OK\r\n"
    
    assert_raise(HTTPTools::MessageIncompleteError) {parser.finish}
  end
  
  def test_empty
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::EmptyMessageError) {parser.finish}
  end
  
end
