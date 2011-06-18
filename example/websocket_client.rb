require 'socket'
require 'digest/md5'
require 'uri'
require 'rubygems'
require 'http_tools'

# Very basic implmentation of a WebSocket client according to
# http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
# 
# Example:
#   sock = WebSocket.new("ws://echo.websocket.org/")
#   sock.puts("test")
#   puts sock.gets
# 
class WebSocket
  attr_accessor :host, :port, :path, :origin
  
  def initialize(url, origin="localhost")
    uri = URI.parse(url)
    @host = uri.host
    @port = uri.port || 80
    @path = uri.path
    @origin = origin
    @socket = TCPSocket.new(host, port)
    handshake(@socket)
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
    number1, key1 = number_and_key
    number2, key2 = number_and_key
    key3 = (0..7).to_a.inject("") {|memo, i| memo << rand(256)}
    header = {
      "Connection" => "Upgrade",
      "Upgrade" => "WebSocket",
      "Origin" => origin,
      "Sec-WebSocket-Key1" => key1,
      "Sec-WebSocket-Key2" => key2}
    hostport = host
    hostport += port.to_s unless port == 80
    socket << HTTPTools::Builder.request(:get, hostport, path, header) << key3
    
    parser = HTTPTools::Parser.new
    code = nil
    
    parser.on(:header) do
      raise "status is not 101" unless parser.status_code == 101
      unless parser.header["Sec-WebSocket-Origin"] == origin
        raise "origin missmatch"
      end
    end
    parser << socket.sysread(1024 * 16) until parser.finished?
    reply = parser.rest
    reply << socket.read(16 - reply.length) if reply.length < 16
    unless reply == Digest::MD5.digest([number1, number2].pack("N*") + key3)
      raise "handshake failed" 
    end
  end
  
  def number_and_key
    spaces = rand(12) + 1
    number = rand((4_294_967_295 / spaces) + 1)
    key = (number * spaces).to_s
    chars = ("!".."/").to_a + (":".."~").to_a
    (rand(12) + 1).times {key[rand(key.length), 0] = chars[rand(chars.length)]}
    spaces.times {key[rand(key.length - 2) + 1, 0] = " "}
    [number, key]
  end
  
  def get_frame(socket)
    type = socket.getbyte
    raise "don't understand frame type #{type}" unless type & 128 == 0
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
