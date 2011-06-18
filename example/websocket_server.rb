require 'socket'
require 'digest/md5'
require 'rubygems'
require 'http_tools'

module WebSocket
  
  # Very basic implmentation of a WebSocket server according to
  # http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
  # 
  # Example:
  #   server = WebSocket::Server.new("localhost", 9292)
  #   while sock = server.accept
  #     Thread.new {loop {sock.puts sock.gets}}
  #   end
  # 
  # Test at http://websocket.org/echo.html, with location ws://localhost:9292/
  # Works with Safari 5.1 and Chrome 12
  # 
  class Server
    def initialize(host, port)
      @server = TCPServer.new(host, port)
    end
    
    def accept
      ServerSocket.new(@server.accept)
    end
  end
  
  class ServerSocket
    def initialize(socket)
      @socket = socket
      handshake(socket)
    end
    
    def gets
      get_frame(@socket)
    end
    
    def puts(str)
      put_frame(@socket, str)
      nil
    end
    
    private
    def handshake(socket)
      parser = HTTPTools::Parser.new
      key1, key2 = nil
      response_header = {"Connection" => "Upgrade", "Upgrade" => "WebSocket"}
      
      parser.on(:header) do
        key1 = parser.header["Sec-WebSocket-Key1"]
        key2 = parser.header["Sec-WebSocket-Key2"]
        location = "ws://" + parser.header["Host"] + parser.path_info
        response_header["Sec-WebSocket-Location"] = location
        response_header["Sec-WebSocket-Origin"] = parser.header["Origin"]
      end
      parser << socket.sysread(1024 * 16) until parser.finished?
      key3 = parser.rest
      key3 << socket.read(8 - key3.length) if key3.length < 8
      
      socket << HTTPTools::Builder.response(101, response_header)
      socket << response_key(key1, key2, key3)
    end
    
    def response_key(key1, key2, key3)
      Digest::MD5.digest([key1, key2].map(&method(:process_key)).join + key3)
    end
    
    def process_key(key)
      [key.scan(/\d+/).join.to_i / key.scan(/ /).length].pack("N*")
    end
    
    def get_frame(socket)
      type = socket.getbyte
      raise unless type == 0
      str = socket.gets("\377")
      str.chomp!("\377")
      str.force_encoding("UTF-8") if str.respond_to?(:force_encoding)
      str
    end
    
    def put_frame(socket, str)
      str.force_encoding("UTF-8") if str.respond_to?(:force_encoding)
      socket.putc("\000")
      written = socket.write(str)
      socket.putc("\377")
      written
    end
    
  end
end
