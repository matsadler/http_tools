require 'uri'
require 'socket'
require 'stringio'
require 'rubygems'
require 'http_tools'

module HTTP
  class Server
    SERVER_NAME = "SERVER_NAME".freeze
    SERVER_PORT = "SERVER_PORT".freeze
    RACK_INPUT = "rack.input".freeze
    NO_BODY = {"GET" => true, "HEAD" => true}
    
    attr_reader :app, :host, :port, :server
    attr_accessor :timeout, :default_env, :multithread
    
    def initialize(app, options={})
      @app = app
      @host = options[:host] || options[:Host] || "0.0.0.0"
      @port = (options[:port] || options[:Port] || 8080).to_s
      @default_env = {SERVER_NAME => host, SERVER_PORT => port}
      @default_env.merge!(options[:default_env]) if options[:default_env]
      @multithread = options[:multithread]
      @server = TCPServer.new(host, port)
      @timeout = 10
    end
    
    def self.run(app, options={})
      new(app, options).listen
    end
    
    def listen
      while socket = server.accept
        thread = Thread.new {on_connection(socket)}
        begin
          thread.join unless multithread
        rescue StandardError, LoadError, SyntaxError
          socket.close rescue nil
        end
      end
    end
    
    private
    def on_connection(socket)
      parser = HTTPTools::Parser.new
      env = nil
      
      parser.on(:header) do
        parser.force_no_body = NO_BODY[parser.request_method]
        env = parser.env.merge!(RACK_INPUT => StringIO.new).merge!(@default_env)
      end
      parser.on(:stream) {|chunk| env[RACK_INPUT] << chunk}
      parser.on(:finish) do |remainder|
        env[RACK_INPUT].rewind
        status, headers, body = app.call(env)
        socket << HTTPTools::Builder.response(status, headers)
        body.each {|chunk| socket << chunk}
        parser.reset
        parser << remainder.lstrip if remainder
        throw :reset
      end
      
      begin
        readable, = select([socket], nil, nil, timeout)
        unless readable
          socket.close
          break
        end
        catch(:reset) {parser << socket.read_nonblock(1024 * 16)}
      rescue EOFError
        socket.close
        break
      end until parser.finished?
      nil
    end
    
  end
end

HTTP::Server.run(Proc.new do |env|
  [200, {"Content-Length" => 6}, ["hello\n"]]
end)