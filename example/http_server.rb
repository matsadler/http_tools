require 'uri'
require 'socket'
require 'stringio'
require 'rubygems'
require 'http_tools'

module HTTP
  class Server
    
    REQUEST_METHOD = "REQUEST_METHOD".freeze
    SCRIPT_NAME = "SCRIPT_NAME".freeze
    PATH_INFO = "PATH_INFO".freeze
    QUERY_STRING = "QUERY_STRING".freeze
    REQUEST_URI = "REQUEST_URI".freeze
    FRAGMENT = "FRAGMENT".freeze
    SERVER_NAME = "SERVER_NAME".freeze
    SERVER_PORT = "SERVER_PORT".freeze
    RACK_VERSION = "rack.version".freeze
    RACK_URL_SCHEME = "rack.url_scheme".freeze
    RACK_INPUT = "rack.input".freeze
    RACK_ERRORS = "rack.errors".freeze
    RACK_MULTITHREAD = "rack.multithread".freeze
    RACK_MULTIPROCESS = "rack.multiprocess".freeze
    RACK_RUN_ONCE = "rack.run_once".freeze
    
    PROTOTYPE_ENV = {
      REQUEST_METHOD => nil,
      SCRIPT_NAME => "".freeze,
      PATH_INFO => "/".freeze,
      QUERY_STRING => "".freeze,
      SERVER_NAME => "".freeze,
      SERVER_PORT => "".freeze,
      RACK_VERSION => [1, 1].freeze,
      RACK_URL_SCHEME => "http".freeze,
      RACK_INPUT => nil,
      RACK_ERRORS => STDERR,
      RACK_MULTITHREAD => false,
      RACK_MULTIPROCESS => false,
      RACK_RUN_ONCE => false}.freeze
    
    GET = "GET".freeze
    HTTP_ = "HTTP_".freeze
    LOWERCASE = "a-z-".freeze
    UPPERCASE = "A-Z_".freeze
    NO_BODY = {"GET" => true, "HEAD" => true}
    
    attr_reader :app, :host, :port, :server
    attr_accessor :timeout, :default_env, :multithread
    
    def initialize(app, options={})
      @app = app
      @host = options[:host] || options[:Host] || "0.0.0.0"
      @port = (options[:port] || options[:Port] || 8080).to_s
      @default_env = options[:default_env] || {}
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
    
    def default_env
      PROTOTYPE_ENV.merge(
        SERVER_NAME => host,
        SERVER_PORT => port,
        RACK_INPUT => StringIO.new).merge!(@default_env)
    end
    
    private
    def on_connection(socket)
      parser = HTTPTools::Parser.new
      env = default_env
      
      parser.on(:method) do |method|
        parser.force_no_body = NO_BODY[method.upcase]
        env[REQUEST_METHOD] = method
      end
      parser.on(:path) {|p, q| env.merge!(PATH_INFO => p, QUERY_STRING => q)}
      parser.on(:uri) {|uri| env[REQUEST_URI] = uri}
      parser.on(:fragment) {|fragment| env[FRAGMENT] = fragment}
      parser.on(:headers) {|headers| merge_in_rack_format(env, headers)}
      parser.on(:stream) {|chunk| env[RACK_INPUT] << chunk}
      parser.on(:finished) do |remainder|
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
    
    def merge_in_rack_format(env, headers)
      headers.each {|k, val| env[HTTP_ + k.tr(LOWERCASE, UPPERCASE)] = val}; env
    end
    
  end
end