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
    
    attr_writer :keepalive
    
    def initialize(host, port=80)
      @host = host
      @port = port
      @pipeline = []
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
        headers[CONTENT_LENGTH] = body.length
      elsif body.respond_to?(:stat)
        headers[CONTENT_LENGTH] = body.stat.size
      else
        raise "Content-Length must be supplied"
      end
      
      request(:post, path, body, headers, &block)
    end
    
    def pipeline
      @pipelining = true
      yield self
      pipeline_requests(@pipeline)
    ensure
      @pipelining = false
    end
    
    def keepalive?
      @keepalive
    end
    
    def keepalive
      self.keepalive, original = true, keepalive?
      yield self
    ensure
      self.keepalive = original
    end
    
    private
    def request(method, path, body=nil, headers={}, response_has_body=true, &b)
      request = {
        :method => method,
        :path => path,
        :body => body,
        :headers => headers,
        :response_has_body => response_has_body,
        :block => b}
      if @pipelining
        @pipeline << request
        nil
      else
        pipeline_requests([request]).first
      end
    end
    
    def pipeline_requests(requests)
      parser = HTTPTools::Parser.new
      parser.allow_html_without_header = true
      responses = []
      
      parser.on(:finish) do |remainder|
        if responses.length < requests.length
          parser.reset
          parser << remainder.lstrip if remainder
          throw :reset
        end
      end
      parser.on(:header) do
        request = requests[responses.length]
        parser.force_no_body = !request[:response_has_body]
        response = Response.new(parser.status_code, parser.message)
        response.headers = parser.header
        parser.on(:stream) {|chunk| response.receive_chunk(chunk)}
        responses.push(response)
      end
      
      requests.each do |r|
        socket << HTTPTools::Builder.request(r[:method], @host, r[:path], r[:headers])
        if body = r[:body]
          socket << body.read(1024 * 16) until body.eof?
        end
      end
      
      begin
        catch(:reset) {parser << socket.sysread(1024 * 16)}
      rescue EOFError
        @socket = nil
        parser.finish
        break
      end until parser.finished?
      
      @socket = nil unless keepalive?
      responses
    end
  end
  
  class Response
    attr_reader :status, :message
    attr_accessor :headers, :body
    
    def initialize(status, message, headers={}, body="")
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
      body << chunk
      @stream_callback.call(chunk) if @stream_callback
    end
    
    def inspect
      bytesize = body.respond_to?(:bytesize) ? body.bytesize : body.to_s.length
      "#<Response #{status} #{message}: #{bytesize} bytes>"
    end
    
    def to_s
      body.to_s
    end
  end
end