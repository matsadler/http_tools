base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class RequestTest < Test::Unit::TestCase
  
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
    
    parser << "GET /foo%20bar/baz.html?key=value#qux HTTP/1.1\r\n\r\n"
    
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
    result = nil
    
    parser.add_listener(:header) do
      result = parser.request_uri
    end
    
    parser << "GET http://example.com/foo HTTP/1.1\r\n\r\n"
    
    assert_equal("http://example.com/foo", result)
  end
  
  def test_path_callback_not_called_with_uri
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:header) do
      result = parser.path_info
    end
    
    parser << "GET http://example.com/foo HTTP/1.1\r\n\r\n"
    
    assert_nil(result)
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
    path = nil
    fragment = nil
    
    parser.add_listener(:header) do
      path = parser.path_info
      fragment = parser.fragment
    end
    
    parser << "GET /foo#bar HTTP/1.1\r\n\r\n"
    
    assert_equal("/foo", path)
    assert_equal("bar", fragment)
  end
  
  def test_fragment_with_uri
    parser = HTTPTools::Parser.new
    uri = nil
    fragment = nil
    
    parser.add_listener(:header) do
      uri = parser.request_uri
      fragment = parser.fragment
    end
    
    parser << "GET http://example.com/foo#bar HTTP/1.1\r\n\r\n"
    
    assert_equal("http://example.com/foo", uri)
    assert_equal("bar", fragment)
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
    
    assert_equal("1.1", version)
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
    
    assert_equal("1.x", version)
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
    
    assert_equal("GET", result)
  end
  
  def test_lowercase_http
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:header) {version = parser.version}
    
    parser << "GET / http/1.1\r\n\r\n"
    
    assert_equal("1.1", version)
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
      parser << "GET / HTTP/1.1\r\nx-invalid\000key: text/plain\r\n"
    end
  end
  
  def test_invalid_header_value_with_non_ascii_character
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
  
  def test_env
    parser = HTTPTools::Parser.new
    env = nil
    parser.on(:header) {env = parser.env}
    
    parser << "GET /test?q=foo HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Accept: text/html\r\n"
    parser << "\r\n"
    
    assert_equal("GET", env["REQUEST_METHOD"])
    assert_equal("", env["SCRIPT_NAME"])
    assert_equal("/test", env["PATH_INFO"])
    assert_equal("q=foo", env["QUERY_STRING"])
    assert_equal(nil, env["SERVER_NAME"])
    assert_equal(nil, env["SERVER_PORT"])
    assert_equal("www.example.com", env["HTTP_HOST"])
    assert_equal("text/html", env["HTTP_ACCEPT"])
    
    assert_equal([1,1], env["rack.version"])
    assert_equal("http", env["rack.url_scheme"])
    assert_equal(nil, env["rack.input"])
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
    assert_equal(nil, env["SERVER_NAME"])
    assert_equal(nil, env["SERVER_PORT"])
    assert_equal("www.example.com", env["HTTP_HOST"])
    assert_equal("chunked", env["HTTP_TRANSFER_ENCODING"])
    assert_equal("X-Checksum", env["HTTP_TRAILER"])
    assert_equal("3e25960a79dbc69b674cd4ec67a72c62", env["HTTP_X_CHECKSUM"])
    
    assert_equal([1,1], env["rack.version"])
    assert_equal("http", env["rack.url_scheme"])
    assert_equal(nil, env["rack.input"])
    assert_equal(STDERR, env["rack.errors"])
    assert_equal(false, env["rack.multithread"])
    assert_equal(false, env["rack.multiprocess"])
    assert_equal(false, env["rack.run_once"])
  end
  
end