module HTTPTools
  
  # HTTPTools::Builder is a provides a simple interface to build HTTP requests &
  # responses. It can be used as a mixin or class methods on HTTPTools::Builder.
  # 
  module Builder
    KEY_VALUE = "%s: %s\r\n".freeze
    
    module_function
    
    # :call-seq: Builder.response(status, headers={}) -> string
    # 
    # Returns a HTTP status line and headers. Status can be a HTTP status code
    # as an integer, or a HTTP status message as a lowercase, underscored
    # symbol.
    #   Builder.response(200, "Content-Type" => "text/html")\
    #=> "HTTP/1.1 200 ok\r\nContent-Type: text/html\r\n\r\n"
    #   
    #   Builder.response(:internal_server_error)\
    #=> "HTTP/1.1 500 Internal Server Error\r\n\r\n"
    # 
    def response(status, headers={})
      "HTTP/1.1 #{STATUS_LINES[status]}\r\n#{format_headers(headers)}\r\n"
    end
    
    # :call-seq: Builder.request(method, host, path="/", headers={}) -> string
    # 
    # Returns a HTTP request line and headers.
    #   Builder.request(:get, "example.com")\
    #=> "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"
    #   
    #   Builder.request(:post, "example.com", "/form", "Accept" => "text/html")\
    #=> "POST" /form HTTP/1.1\r\nHost: example.com\r\nAccept: text/html\r\n\r\n"
    # 
    def request(method, host, path="/", headers={})
      "#{method.to_s.upcase} #{path} HTTP/1.1\r\nHost: #{host}\r\n#{
        format_headers(headers)}\r\n"
    end
    
    def format_headers(headers)
      headers.inject("") {|buffer, kv| buffer << KEY_VALUE % kv}
    end
    private :format_headers
    class << self
      private :format_headers
    end
    
  end
end