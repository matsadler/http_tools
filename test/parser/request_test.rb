base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class ParserRequestTest < Test::Unit::TestCase
  
  def test_get
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:header) do
      result = parser.request_method
    end
    
    parser << "GET / HTTP/1.1\r\n\r\n"
    
    assert_equal("GET", result)
  end
  
  def test_post
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:header) do
      result = parser.request_method
    end
    
    parser << "POST / HTTP/1.1\r\n\r\n"
    
    assert_equal("POST", result)
  end
  
  def test_empty_path
    parser = HTTPTools::Parser.new
    path, query = nil
    
    parser.add_listener(:header) do
      path, query = parser.path_info, parser.query_string
    end
    
    parser << "GET / HTTP/1.1\r\n\r\n"
    
    assert_equal("/", path)
    assert_equal("", query)
  end
  
  def test_basic_path
    parser = HTTPTools::Parser.new
    path, query = nil
    
    parser.add_listener(:header) do
      path, query = parser.path_info, parser.query_string
    end
    
    parser << "GET /foo HTTP/1.1\r\n\r\n"
    
    assert_equal("/foo", path)
    assert_equal("", query)
  end
  
  def test_complicated_path
    parser = HTTPTools::Parser.new
    path, query = nil
    
    parser.add_listener(:header) do
      path, query = parser.path_info, parser.query_string
    end
    
    parser << "GET /foo%20bar/baz.html?key=value HTTP/1.1\r\n\r\n"
    
    assert_equal("/foo%20bar/baz.html", path)
    assert_equal("key=value", query)
  end
  
  def test_invalid_path
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET \\ HTTP/1.1\r\n\r\n"
    end
  end
  
  def test_uri
    parser = HTTPTools::Parser.new
    uri, path, query = nil
    
    parser.add_listener(:header) do
      uri = parser.request_uri
      path = parser.path_info
      query = parser.query_string
    end
    
    parser << "GET http://example.com/foo?bar=baz HTTP/1.1\r\n\r\n"
    
    assert_equal("http://example.com/foo?bar=baz", uri)
    assert_equal("/foo", path)
    assert_equal("bar=baz", query)
  end
  
  def test_uri_callback_called_with_path
    parser = HTTPTools::Parser.new
    uri = nil
    path = nil
    query = nil
    
    parser.add_listener(:header) do
      uri = parser.request_uri
      path = parser.path_info
      query = parser.query_string
    end
    
    parser << "GET /foo/bar.html?key=value HTTP/1.1\r\n\r\n"
    
    assert_equal("/foo/bar.html?key=value", uri)
    assert_equal("/foo/bar.html", path)
    assert_equal("key=value", query)
  end
  
  def test_fragment_with_path
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET /foo#bar HTTP/1.1\r\n\r\n"
    end
  end
  
  def test_fragment_with_unfinished_path
    parser = HTTPTools::Parser.new
    
    error = assert_raise(HTTPTools::ParseError) do
      parser << "GET /foo#ba"
    end
  end
  
  def test_fragment_with_uri
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET http://example.com/foo#bar HTTP/1.1\r\n\r\n"
    end
  end
  
  def test_with_header
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "\r\n"
    
    assert_equal("GET", method)
    assert_equal("/", path)
    assert_equal({"Host" => "www.example.com"}, headers)
  end
  
  def test_with_headers
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Accept: text/plain\r\n"
    parser << "\r\n"
    
    assert_equal("GET", method)
    assert_equal("/", path)
    assert_equal({"Host"=>"www.example.com", "Accept"=>"text/plain"}, headers)
  end
  
  def test_sub_line_chunks
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GE"
    parser << "T /foo/"
    parser << "bar HT"
    parser << "TP/1.1\r\n"
    parser << "Host: www.exam"
    parser << "ple.com\r\n"
    parser << "Accep"
    parser << "t: text/plain\r\n\r\n"
    
    assert_equal("GET", method)
    assert_equal("/foo/bar", path)
    assert_equal({"Host"=>"www.example.com", "Accept"=>"text/plain"}, headers)
  end
  
  def test_sub_line_chunks_2
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "POST"
    parser << " /bar/foo"
    parser << " HTTP/"
    parser << "1."
    parser << "1\r\n"
    parser << "Host: "
    parser << "www.example.com\r\n"
    parser << "Content-Length:"
    parser << " 11\r\n\r\n"
    parser << "hello="
    parser << ""
    parser << "world"
    
    assert_equal("POST", method)
    assert_equal("/bar/foo", path)
    assert_equal({"Host"=>"www.example.com", "Content-Length"=>"11"}, headers)
  end
  
  def test_all_at_once
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    request = "GET /foo/bar HTTP/1.1\r\n"
    request << "Host: www.example.com\r\nAccept: text/plain\r\n\r\n"
    
    parser << request
    
    assert_equal("GET", method)
    assert_equal("/foo/bar", path)
    assert_equal({"Host"=>"www.example.com", "Accept"=>"text/plain"}, headers)
  end
  
  def test_accepts_imaginary_method
    parser = HTTPTools::Parser.new
    method = nil
    
    parser.add_listener(:header) {method = parser.request_method}
    
    parser << "UNICORNS / HTTP/1.1\r\n\r\n"
    
    assert_equal("UNICORNS", method)
  end
  
  def test_without_http
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GET /\r\nHost: www.example.com\r\n\r\n"
    
    assert_equal("GET", method)
    assert_equal("/", path)
    assert_equal({"Host"=>"www.example.com"}, headers)
  end
  
  def test_unknown_protocol
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "GET / SPDY/1.1\r\n"}
  end
  
  def test_protocol_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "GET / HTTP/1.1\r\n\r\n"
    
    assert_equal("HTTP/1.1", version)
  end
  
  def test_protocol_without_version
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "GET / HTTP\r\n\r\n"}
  end
  
  def test_one_dot_x_protocol_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "GET / HTTP/1.x\r\n\r\n"
    
    assert_equal("HTTP/1.x", version)
  end
  
  def test_finish_without_body_trigger
    parser = HTTPTools::Parser.new
    
    parser << "GET / HTTP/1.1\r\n\r\n"
    
    assert(parser.finished?, "parser should be finished")
  end
  
  def test_finish_with_content_length_body_trigger
    parser = HTTPTools::Parser.new
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Content-Length: 5\r\n\r\n"
    
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_finish_with_transfer_encoding_body_trigger
    parser = HTTPTools::Parser.new
    parser << "GET / HTTP/1.1\r\n"
    parser << "Transfer-Encoding: chunked\r\n\r\n"
    
    assert(!parser.finished?, "parser should not be finished")
  end
  
  def test_reset
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    calls = 0
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
      calls += 1
    end
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Accept: text/plain\r\n"
    parser << "\r\n"
    
    assert_equal("GET", method)
    assert_equal("/", path)
    assert_equal({"Host"=>"www.example.com", "Accept"=>"text/plain"}, headers)
    assert_equal(1, calls)
    
    parser.reset
    
    parser << "POST /example HTTP/1.1\r\n"
    parser << "Host: www.test.co.uk\r\n"
    parser << "Accept: text/html\r\n"
    parser << "\r\n"
    
    assert_equal("POST", method)
    assert_equal("/example", path)
    assert_equal({"Host"=>"www.test.co.uk", "Accept"=>"text/html"}, headers)
    assert_equal(2, calls)
  end
  
  def test_default_body_with_reset
    parser = HTTPTools::Parser.new
    
    parser << "POST /example HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Content-Length: 3\r\n\r\n"
    parser << "foo"
    
    assert_equal("foo", parser.body)
    
    parser.reset
    
    parser << "POST /example HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Content-Length: 3\r\n\r\n"
    parser << "bar"
    
    assert_equal("bar", parser.body)
  end
  
  def test_rest_with_request_in_one_chunk
    parser = HTTPTools::Parser.new
    
    parser << "POST /example HTTP/1.1\r\nContent-Length: 4\r\n\r\ntest"
    
    assert_equal("test", parser.body)
    assert_equal("", parser.rest)
  end
  
  def test_rest_with_request_and_next_in_one_chunk
    parser = HTTPTools::Parser.new
    
    parser << "POST /example HTTP/1.1\r\nContent-Length: 4\r\n\r\ntestPOST /ex"
    
    assert_equal("test", parser.body)
    assert_equal("POST /ex", parser.rest)
  end
  
  def test_rest_size
    parser = HTTPTools::Parser.new
    
    parser << "GET /foo"
    
    assert_equal("/foo".length, parser.rest_size)
    
    parser << " HTTP/1.1\r\nHost: www.example.com"
    
    assert_equal("www.example.com".length, parser.rest_size)
  end
  
  def test_not_a_http_request
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "not a http request"}
  end
  
  def test_data_past_end
    parser = HTTPTools::Parser.new
    parser << "POST /example HTTP/1.1\r\n"
    parser << "Content-Length: 8\r\n"
    parser << "\r\n"
    parser << "test=foo"
    
    assert_raise(HTTPTools::EndOfMessageError) {parser << "more"}
  end
  
  def test_lowecase_method
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:header) do
      result = parser.request_method
    end
    
    parser << "get / HTTP/1.1\r\n\r\n"
    
    assert_equal("get", result)
  end
  
  def test_lowercase_http
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "GET / http/1.1\r\n\r\n"
    
    assert_equal("http/1.1", version)
  end
  
  def test_invalid_version
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "GET / HTTP/one dot one\r\n"}
  end
  
  def test_invalid_header_key_with_control_character
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET / HTTP/1.1\r\nx-invalid\0key: text/plain\r\n"
    end
  end
  
  def test_invalid_header_key_with_non_ascii_character
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET / HTTP/1.1\r\nx-invalid\u2014key: text/plain\r\n"
    end
  end
  
  def test_invalid_header_value_with_non_control_character
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET / HTTP/1.1\r\nAccept: \000text/plain\r\n"
    end
  end
  
  def test_error_callback
    parser = HTTPTools::Parser.new
    error = nil
    parser.on(:error) {|e| error = e}
    
    assert_nothing_raised(Exception) {parser << "1"}
    assert_instance_of(HTTPTools::ParseError, error)
  end
  
  def test_upgrade_websocket_hixie_76
    parser = HTTPTools::Parser.new
    method, path, headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GET /demo HTTP/1.1\r\n"
    parser << "Host: example.com\r\n"
    parser << "Connection: Upgrade\r\n"
    parser << "Sec-WebSocket-Key2: 12998 5 Y3 1  .P00\r\n"
    parser << "Sec-WebSocket-Protocol: sample\r\n"
    parser << "Upgrade: WebSocket\r\n"
    parser << "Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5\r\n"
    parser << "Origin: http://example.com\r\n\r\n^n:ds[4U"
    
    assert_equal("GET", method)
    assert_equal("/demo", path)
    assert_equal({
      "Host" => "example.com",
      "Connection" => "Upgrade",
      "Sec-WebSocket-Key2" => "12998 5 Y3 1  .P00",
      "Upgrade" => "WebSocket",
      "Sec-WebSocket-Protocol" => "sample",
      "Sec-WebSocket-Key1" => "4 @1  46546xW%0l 1 5",
      "Origin" => "http://example.com"}, headers)
    assert(parser.finished?, "Parser should be finished.")
    assert_equal(parser.rest, "^n:ds[4U")
  end
  
  def test_upgrade_websocket_hybi_09
    parser = HTTPTools::Parser.new
    method, path, headers = nil
    
    parser.add_listener(:header) do
      method = parser.request_method
      path = parser.path_info
      headers = parser.header
    end
    
    parser << "GET /chat HTTP/1.1\r\n"
    parser << "Host: server.example.com\r\n"
    parser << "Upgrade: websocket\r\n"
    parser << "Connection: Upgrade\r\n"
    parser << "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
    parser << "Sec-WebSocket-Origin: http://example.com\r\n"
    parser << "Sec-WebSocket-Protocol: chat, superchat\r\n"
    parser << "Sec-WebSocket-Version: 8\r\n\r\n"
    
    assert_equal("GET", method)
    assert_equal("/chat", path)
    assert_equal({
      "Host" => "server.example.com",
      "Upgrade" => "websocket",
      "Connection" => "Upgrade",
      "Sec-WebSocket-Key" => "dGhlIHNhbXBsZSBub25jZQ==",
      "Sec-WebSocket-Origin" => "http://example.com",
      "Sec-WebSocket-Protocol" => "chat, superchat",
      "Sec-WebSocket-Version" => "8"}, headers)
    assert(parser.finished?, "Parser should be finished.")
    assert_equal(parser.rest, "")
  end
  
  def test_env
    parser = HTTPTools::Parser.new
    env = nil
    parser.on(:finish) {env = parser.env}
    
    parser << "GET /test?q=foo HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Accept: text/html\r\n"
    parser << "\r\n"
    
    assert_equal("GET", env["REQUEST_METHOD"])
    assert_equal("", env["SCRIPT_NAME"])
    assert_equal("/test", env["PATH_INFO"])
    assert_equal("q=foo", env["QUERY_STRING"])
    assert_equal("www.example.com", env["SERVER_NAME"])
    assert(!env.key?("SERVER_PORT"), "env must not contain SERVER_PORT")
    assert_equal("www.example.com", env["HTTP_HOST"])
    assert_equal("text/html", env["HTTP_ACCEPT"])
    
    assert_equal([1,1], env["rack.version"])
    assert_equal("http", env["rack.url_scheme"])
    assert_instance_of(StringIO, env["rack.input"])
    assert_equal("", env["rack.input"].read)
    assert_equal(STDERR, env["rack.errors"])
    assert_equal(false, env["rack.multithread"])
    assert_equal(false, env["rack.multiprocess"])
    assert_equal(false, env["rack.run_once"])
  end
  
  def test_env_with_trailer
    parser = HTTPTools::Parser.new
    env = nil
    parser.on(:finish) {env = parser.env}
    
    parser << "POST /submit HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Transfer-Encoding: chunked\r\n"
    parser << "Trailer: X-Checksum\r\n"
    parser << "\r\n"
    parser << "5\r\nHello\r\n"
    parser << "6\r\n world\r\n0\r\n"
    parser << "X-Checksum: 3e25960a79dbc69b674cd4ec67a72c62\r\n"
    parser << "\r\n"
    
    assert_equal("POST", env["REQUEST_METHOD"])
    assert_equal("", env["SCRIPT_NAME"])
    assert_equal("/submit", env["PATH_INFO"])
    assert_equal("", env["QUERY_STRING"])
    assert_equal("www.example.com", env["SERVER_NAME"])
    assert(!env.key?("SERVER_PORT"), "env must not contain SERVER_PORT")
    assert_equal("www.example.com", env["HTTP_HOST"])
    assert_equal("chunked", env["HTTP_TRANSFER_ENCODING"])
    assert_equal("X-Checksum", env["HTTP_TRAILER"])
    assert_equal("3e25960a79dbc69b674cd4ec67a72c62", env["HTTP_X_CHECKSUM"])
    
    assert_equal([1,1], env["rack.version"])
    assert_equal("http", env["rack.url_scheme"])
    assert_instance_of(StringIO, env["rack.input"])
    assert_equal("Hello world", env["rack.input"].read)
    assert_equal(STDERR, env["rack.errors"])
    assert_equal(false, env["rack.multithread"])
    assert_equal(false, env["rack.multiprocess"])
    assert_equal(false, env["rack.run_once"])
  end
  
  def test_env_server_port
    parser = HTTPTools::Parser.new
    env = nil
    parser.on(:finish) {env = parser.env}
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Host: localhost:9292\r\n"
    parser << "\r\n"
    
    assert_equal("localhost", env["SERVER_NAME"])
    assert_equal("9292", env["SERVER_PORT"])
    assert_equal("localhost:9292", env["HTTP_HOST"])
  end
  
  def test_env_post
    parser = HTTPTools::Parser.new
    env = nil
    parser.on(:finish) {env = parser.env}
    
    parser << "POST / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Content-Length: 7\r\n"
    parser << "Content-Type: application/x-www-form-urlencoded\r\n"
    parser << "\r\n"
    parser << "foo=bar"
    
    assert_equal("POST", env["REQUEST_METHOD"])
    assert(!env.key?("HTTP_CONTENT_LENGTH"), "env must not contain HTTP_CONTENT_LENGTH")
    assert(!env.key?("HTTP_CONTENT_TYPE"), "env must not contain HTTP_CONTENT_TYPE")
    assert_equal("7", env["CONTENT_LENGTH"])
    assert_equal("application/x-www-form-urlencoded", env["CONTENT_TYPE"])
    
    assert_instance_of(StringIO, env["rack.input"])
    assert_equal("foo=bar", env["rack.input"].read)
  end
  
  def test_env_with_stream_listener
    parser = HTTPTools::Parser.new
    env = nil
    body = ""
    parser.on(:finish) {env = parser.env}
    parser.on(:stream) {|chunk| body << chunk}
    
    parser << "POST / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Content-Length: 7\r\n"
    parser << "\r\n"
    parser << "foo=bar"
    
    assert_equal("foo=bar", body)
    assert_equal(nil, env["rack.input"])
  end
  
  def test_env_lowercase_method
    parser = HTTPTools::Parser.new
    
    parser << "get /test?q=foo HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n\r\n"
    
    assert_equal("GET", parser.env["REQUEST_METHOD"])
  end
  
  def test_env_no_host
    parser = HTTPTools::Parser.new
    env = nil
    
    parser << "GET /test?q=foo HTTP/1.1\r\n\r\n"
    
    assert_nothing_raised(NoMethodError) do
      env = parser.env
    end
    assert(!env.key?("HTTP_HOST"), "env must not contain HTTP_HOST")
    assert(!env.key?("SERVER_NAME"), "env must not contain SERVER_NAME")
    assert(!env.key?("SERVER_PORT"), "env must not contain SERVER_PORT")
  end
  
  def test_inspect
    parser = HTTPTools::Parser.new
    
    assert_match(/#<HTTPTools::Parser:0x[a-f0-9]+ line 1, char 1 start>/, parser.inspect)
  end
  
  def test_inspect_position
    parser = HTTPTools::Parser.new
    
    parser << "GET / HTTP/1.1\r\nHost: foo."
    
    assert_match(/#<HTTPTools::Parser:0x[a-f0-9]+ line 2, char 7 value>/, parser.inspect)
  end
  
end
