require 'uri'
require 'socket'
require 'stringio'
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
# Streaming response:
#   client.get(uri.path) do |response|
#     puts "#{response.status} #{response.message}"
#     response.stream do |chunk|
#       print chunk
#     end
#   end
#   
module HTTP
  class Client
    include HTTPTools::Encoding
    
    CONTENT_TYPE = "Content-Type".freeze
    CONTENT_LENGTH = "Content-Length".freeze
    WWW_FORM = "application/x-www-form-urlencoded".freeze
    
    def initialize(host, port=80)
      @host = host
      @port = port
    end
    
    def socket
      @socket ||= TCPSocket.new(@host, @port)
    end
    
    def head(path, headers={})
      request(:head, path, nil, headers, false)
    end
    
    def get(path, headers={}, &block)
      request(:get, path, nil, headers, &block)
    end
    
    def post(path, body="", headers={}, &block)
      headers[CONTENT_TYPE] ||= WWW_FORM
      unless body.respond_to?(:read)
        if headers[CONTENT_TYPE] == WWW_FORM && body.respond_to?(:map) &&
          !body.kind_of?(String)
          body = www_form_encode(body)
        end
        body = StringIO.new(body.to_s)
      end
      if headers[CONTENT_LENGTH]
        # ok
      elsif body.respond_to?(:length)
        headers[CONTENT_LENGTH] ||= body.length
      elsif body.respond_to?(:stat)
        headers[CONTENT_LENGTH] ||= body.stat.size
      else
        raise "Content-Length must be supplied"
      end
      
      request(:post, path, body, headers, &block)
    end
    
    private
    def request(method, path, request_body=nil, request_headers={}, response_has_body=true, &block)
      parser = HTTPTools::Parser.new
      parser.force_no_body = !response_has_body
      response = nil
      
      parser.add_listener(:status) {|s, m| response = Response.new(s, m)}
      parser.add_listener(:headers) do |headers|
        response.headers = headers
        block.call(response) if block
      end
      if block
        parser.add_listener(:stream) {|chunk| response.receive_chunk(chunk)}
      else
        parser.add_listener(:body) {|body| response.body = body}
      end
      
      socket << HTTPTools::Builder.request(method, @host, path, request_headers)
      if request_body
        socket << request_body.read(1024 * 16) until request_body.eof?
      end
      
      until parser.finished?
        begin
          readable, = select([socket], nil, nil)
          parser << socket.read_nonblock(1024 * 16) if readable.any?
        rescue EOFError
          parser.finish
          break
        end
      end
      response
    end
  end
  
  class Response
    attr_reader :status, :message
    attr_accessor :headers, :body
    
    def initialize(status, message, headers={}, body=nil)
      @status = status
      @message = message
      @headers = headers
      @body = body
    end
    
    def stream(&block)
      @stream_callback = block
      nil
    end
    
    def receive_chunk(chunk) # :nodoc:
      @stream_callback.call(chunk) if @stream_callback
    end
    
    def inspect
      bytesize = body.respond_to?(:bytesize) ? body.bytesize : body.to_s.length
      "#<Response #{status} #{message}: #{bytesize} bytes>"
    end
  end
end