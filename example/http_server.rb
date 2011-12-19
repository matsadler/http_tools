require 'socket'
require 'rubygems'
require 'http_tools'

module HTTP
  
  # Basic Rack HTTP server.
  # 
  # Usage:
  # 
  #   app = lambda {|env| [200, {"Content-Length" => "3"}, ["Hi\n"]]}
  #   HTTP::Server.run(app)
  # 
  class Server
    
    def initialize(app, options={})
      @host = options[:host] || options[:Host] || "0.0.0.0"
      @port = (options[:port] || options[:Port] || 9292).to_s
      @app = app
    end
    
    def self.run(app, options={})
      new(app, options).listen
    end
    
    def listen
      server = TCPServer.new(@host, @port)
      while socket = server.accept
        Thread.new {on_connection(socket)}
      end
    end
    
    private
    
    def on_connection(socket)
      parser = HTTPTools::Parser.new
      
      parser.on(:finish) do
        env = parser.env.merge!("rack.multithread" => true)
        status, header, body = @app.call(env)
        
        keep_alive = parser.header["Connection"] != "close"
        header["Connection"] = keep_alive ? "Keep-Alive" : "close"
        socket << HTTPTools::Builder.response(status, header)
        body.each {|chunk| socket << chunk}
        body.close if body.respond_to?(:close)
        remainder = parser.rest.lstrip
        parser.reset << remainder and throw :reset if keep_alive
      end
      
      begin
        readable, = select([socket], nil, nil, 30)
        break unless readable
        catch(:reset) {parser << socket.read_nonblock(1024 * 16)}
      rescue EOFError
        break
      end until parser.finished?
      
    rescue StandardError, LoadError, SyntaxError => e
      STDERR.puts("#{e.class}: #{e.message} #{e.backtrace.join("\n")}")
    ensure
      socket.close
    end
    
  end
end
