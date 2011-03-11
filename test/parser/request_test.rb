base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class RequestTest < Test::Unit::TestCase
  
  def test_get
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:method) do |method|
      result = method
    end
    
    parser << "GET / HTTP/1.1\r\n"
    
    assert_equal("GET", result)
  end
  
  def test_post
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:method) do |method|
      result = method
    end
    
    parser << "POST / HTTP/1.1\r\n"
    
    assert_equal("POST", result)
  end
  
  def test_empty_path
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:path) do |path, query|
      result = path
    end
    
    parser << "GET / HTTP/1.1\r\n"
    
    assert_equal("/", result)
  end
  
  def test_basic_path
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:path) do |path, query|
      result = path
    end
    
    parser << "GET /foo HTTP/1.1\r\n"
    
    assert_equal("/foo", result)
  end
  
  def test_complicated_path
    parser = HTTPTools::Parser.new
    path = nil
    query = nil
    
    parser.add_listener(:path) do |p, q|
      path = p
      query = q
    end
    
    parser << "GET /foo%20bar/baz.html?key=value#qux HTTP/1.1\r\n"
    
    assert_equal("/foo%20bar/baz.html", path)
    assert_equal("key=value", query)
  end
  
  def test_invalid_path
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) do
      parser << "GET \\ HTTP/1.1\r\n"
    end
  end
  
  def test_uri
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:uri) do |uri|
      result = uri
    end
    
    parser << "GET http://example.com/foo HTTP/1.1\r\n"
    
    assert_equal("http://example.com/foo", result)
  end
  
  def test_path_callback_not_called_with_uri
    parser = HTTPTools::Parser.new
    result = nil
    
    parser.add_listener(:path) do |path, query|
      result = path
    end
    
    parser << "GET http://example.com/foo HTTP/1.1\r\n"
    
    assert_nil(result)
  end
  
  def test_uri_callback_called_with_path
    parser = HTTPTools::Parser.new
    uri = nil
    path = nil
    query = nil
    
    parser.add_listener(:uri) {|u| uri = u}
    parser.add_listener(:path) do |p, q|
      path = p
      query = q
    end
    
    parser << "GET /foo/bar.html?key=value HTTP/1.1\r\n"
    
    assert_equal("/foo/bar.html?key=value", uri)
    assert_equal("/foo/bar.html", path)
    assert_equal("key=value", query)
  end
  
  def test_fragment_with_path
    parser = HTTPTools::Parser.new
    path = nil
    fragment = nil
    
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:fragment) {|f| fragment = f}
    
    parser << "GET /foo#bar HTTP/1.1\r\n"
    
    assert_equal("/foo", path)
    assert_equal("bar", fragment)
  end
  
  def test_fragment_with_uri
    parser = HTTPTools::Parser.new
    uri = nil
    fragment = nil
    
    parser.add_listener(:uri) {|u| uri = u}
    parser.add_listener(:fragment) {|f| fragment = f}
    
    parser << "GET http://example.com/foo#bar HTTP/1.1\r\n"
    
    assert_equal("http://example.com/foo", uri)
    assert_equal("bar", fragment)
  end
  
  def test_with_header
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:method) {|m| method = m}
    
    parser << "UNICORNS / HTTP/1.1\r\n"
    
    assert_equal("UNICORNS", method)
  end
  
  def test_without_http
    parser = HTTPTools::Parser.new
    method = nil
    path = nil
    headers = nil
    
    parser.add_listener(:method) {|m| method = m}
    parser.add_listener(:path) {|p, q| path = p}
    parser.add_listener(:headers) {|h| headers = h}
    
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
    
    parser.add_listener(:version) {|v| version = v}
    
    parser << "GET / HTTP/1.1\r\n"
    
    assert_equal("1.1", version)
  end
  
  def test_protocol_without_version
    parser = HTTPTools::Parser.new
    
    assert_raise(HTTPTools::ParseError) {parser << "GET / HTTP\r\n"}
  end
  
  def test_one_dot_x_protocol_version
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:version) {|v| version = v}
    
    parser << "GET / HTTP/1.x\r\n"
    
    assert_equal("1.x", version)
  end
  
  def test_reset
    parser = HTTPTools::Parser.new
    method = nil
    method_calls = 0
    path = nil
    path_calls = 0
    headers = nil
    header_calls = 0
    
    parser.add_listener(:method) {|m| method = m; method_calls += 1}
    parser.add_listener(:path) {|p, q| path = p; path_calls += 1}
    parser.add_listener(:headers) {|h| headers = h; header_calls += 1}
    
    parser << "GET / HTTP/1.1\r\n"
    parser << "Host: www.example.com\r\n"
    parser << "Accept: text/plain\r\n"
    parser << "\r\n"
    
    assert_equal("GET", method)
    assert_equal("/", path)
    assert_equal({"Host"=>"www.example.com", "Accept"=>"text/plain"}, headers)
    assert_equal([1, 1, 1], [method_calls, path_calls, header_calls])
    
    parser.reset
    
    parser << "POST /example HTTP/1.1\r\n"
    parser << "Host: www.test.co.uk\r\n"
    parser << "Accept: text/html\r\n"
    parser << "\r\n"
    
    assert_equal("POST", method)
    assert_equal("/example", path)
    assert_equal({"Host"=>"www.test.co.uk", "Accept"=>"text/html"}, headers)
    assert_equal([2, 2, 2], [method_calls, path_calls, header_calls])
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
    
    parser.add_listener(:method) do |method|
      result = method
    end
    
    parser << "get / HTTP/1.1\r\n"
    
    assert_equal("GET", result)
  end
  
  def test_lowercase_http
    parser = HTTPTools::Parser.new
    version = nil
    
    parser.add_listener(:version) {|v| version = v}
    
    parser << "GET / http/1.1\r\n"
    
    assert_equal("1.1", version)
  end
  
  def test_delegate
    request_class = Class.new
    request_class.class_eval do
      attr_reader :http_method, :path, :headers, :body
      def on_method(name)
        @http_method = name
      end
      def on_path(path, query)
        @path = path
        @query = query
      end
      def on_headers(headers)
        @headers = headers
      end
      def on_body(body)
        @body = body
      end
    end
    request = request_class.new
    
    parser = HTTPTools::Parser.new(request)
    parser << "POST /test HTTP/1.1\r\n"
    parser << "Content-Length: 13\r\n"
    parser << "\r\n"
    parser << "query=example"
    
    assert_equal("POST", request.http_method)
    assert_equal("/test", request.path)
    assert_equal({"Content-Length" => "13"}, request.headers)
    assert_equal("query=example", request.body)
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
  
end