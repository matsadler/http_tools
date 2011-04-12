require 'socket'
require 'stringio'
require 'rubygems'
require 'http_tools'

module HTTP
  class Server
    RACK_INPUT = "rack.input".freeze
    CONNECTION = "Connection".freeze
    KEEP_ALIVE = "Keep-Alive".freeze
    CLOSE = "close".freeze
    ONE_ONE = "1.1".freeze
    
    def initialize(app, options={})
      host = options[:host] || options[:Host] || "0.0.0.0"
      port = (options[:port] || options[:Port] || 9292).to_s
      @app = app
      @instance_env = {"SERVER_NAME" => host, "SERVER_PORT" => port,
        "rack.multithread" => true}
      @server = TCPServer.new(host, port)
      @server.listen(1024)
    end
    
    def self.run(app, options={})
      new(app, options).listen
    end
    
    def listen
      while socket = @server.accept
        Thread.new do
          begin
            on_connection(socket)
          rescue StandardError, LoadError, SyntaxError => e
            STDERR.puts("#{e.class}: #{e.message} #{e.backtrace.join("\n")}")
          end
        end
      end
    end
    
    private
    def on_connection(socket)
      parser = HTTPTools::Parser.new
      env, input = nil
      
      parser.on(:header) do
        input = StringIO.new
        env = parser.env.merge!(RACK_INPUT => input).merge!(@instance_env)
      end
      parser.on(:stream) {|chunk| input << chunk}
      parser.on(:finish) do |remainder|
        input.rewind
        status, header, body = @app.call(env)
        keep_alive = keep_alive?(parser.version, parser.header[CONNECTION])
        header[CONNECTION] = keep_alive ? KEEP_ALIVE : CLOSE
        socket << HTTPTools::Builder.response(status, header)
        body.each {|chunk| socket << chunk}
        body.close if body.respond_to?(:close)
        if keep_alive
          parser.reset
          parser << remainder.lstrip if remainder
          throw :reset
        end
      end
      
      begin
        readable, = select([socket], nil, nil, 30)
        break unless readable
        catch(:reset) {parser << socket.read_nonblock(1024 * 16)}
      rescue EOFError
        break
      end until parser.finished?
      socket.close
    end
    
    def keep_alive?(http_version, connection)
      http_version == ONE_ONE && connection != CLOSE || connection == KEEP_ALIVE
    end
    
  end
end
