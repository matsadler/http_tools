require 'socket'
require 'rubygems'
require 'http_tools'

# Usage:
#   uri = URI.parse("http://example.com/")
#   client = HTTP::Client.new(uri.host, uri.port)
#   response = client.get(uri.path)
#   
#   puts "#{response.status} #{response.message}"
#   puts response.headers.inspect
#   puts response.body
#   
module HTTP
  class Client
    Response = Struct.new(:status, :message, :headers, :body)
    
    def initialize(host, port=80)
      @host, @port = host, port
    end
    
    def head(path, headers={})
      request(:head, path, nil, headers, false)
    end
    
    def get(path, headers={})
      request(:get, path, nil, headers)
    end
    
    def post(path, body=nil, headers={})
      request(:post, path, body, headers)
    end
    
    def put(path, body=nil, headers={})
      request(:put, path, body, headers)
    end
    
    def delete(path, headers={})
      request(:delete, path, nil, headers)
    end
    
    private
    def request(method, path, body=nil, headers={}, response_has_body=true)
      parser = HTTPTools::Parser.new
      parser.force_no_body = !response_has_body
      response = nil
      
      parser.on(:finish) do
        code, message = parser.status_code, parser.message
        response = Response.new(code, message, parser.header, parser.body)
      end
      
      socket = TCPSocket.new(@host, @port)
      socket << HTTPTools::Builder.request(method, @host, path, headers)
      socket << body if body
      begin
        parser << socket.sysread(1024 * 16)
      rescue EOFError
        break parser.finish
      end until parser.finished?
      socket.close
      
      response
    end
  end
end
