require 'strscan'

module HTTPTools
  
  # HTTPTools::Parser is a pure Ruby HTTP request & response parser with an
  # evented API.
  # 
  # The HTTP message can be fed in to the parser piece by piece as it comes over
  # the wire, and the parser will call its callbacks as it works it's way
  # through the message.
  # 
  # Example:
  #   parser = HTTPTools::Parser.new
  #   parser.on(:header) do |header|
  #     puts parser.status_code + " " + parser.request_method
  #     puts parser.header.inspect
  #   end
  #   parser.on(:stream) {|chunk| print chunk}
  #   
  #   parser << "HTTP/1.1 200 OK\r\n"
  #   parser << "Content-Length: 20\r\n\r\n"
  #   parser << "<h1>Hello world</h1>"
  # 
  # Prints:
  #   200 OK
  #   {"Content-Length" => "20"}
  #   <h1>Hello world</h1>
  # 
  class Parser
    include Encoding
    
    COLON = ":".freeze
    KEY_TERMINATOR = ": ".freeze
    CONTENT_LENGTH = "Content-Length".freeze
    TRANSFER_ENCODING = "Transfer-Encoding".freeze
    TRAILER = "Trailer".freeze
    CONNECTION = "Connection".freeze
    CLOSE = "close".freeze
    CHUNKED = "chunked".freeze
    EVENTS = %W{header stream trailer finish error}.map {|e| e.freeze}.freeze
    
    REQUEST_METHOD = "REQUEST_METHOD".freeze
    PATH_INFO = "PATH_INFO".freeze
    QUERY_STRING = "QUERY_STRING".freeze
    SERVER_NAME = "SERVER_NAME".freeze
    SERVER_PORT = "SERVER_PORT".freeze
    HTTP_HOST = "HTTP_HOST".freeze
    
    PROTOTYPE_ENV = {
      "SCRIPT_NAME" => "".freeze,
      "rack.version" => [1, 1].freeze,
      "rack.url_scheme" => "http".freeze,
      "rack.errors" => STDERR,
      "rack.multithread" => false,
      "rack.multiprocess" => false,
      "rack.run_once" => false}.freeze
    
    HTTP_ = "HTTP_".freeze
    LOWERCASE = "a-z-".freeze
    UPPERCASE = "A-Z_".freeze
    NO_HTTP_ = {"CONTENT_LENGTH" => true, "CONTENT_TYPE" => true}
    
    attr_reader :state # :nodoc:
    attr_reader :request_method, :path_info, :query_string, :request_uri,
      :version, :status_code, :message, :header, :trailer
    
    # Force parser to expect and parse a trailer when Trailer header missing.
    attr_accessor :force_trailer
    
    # Skip parsing the body, e.g. with the response to a HEAD request.
    attr_accessor :force_no_body
    
    # Allow responses with no status line or headers if it looks like HTML.
    attr_accessor :allow_html_without_header
    
    # :call-seq: Parser.new -> parser
    # 
    # Create a new HTTPTools::Parser.
    # 
    def initialize
      @state = :start
      @buffer = StringScanner.new("")
      @header = {}
      @trailer = {}
    end
    
    # :call-seq: parser.concat(data) -> parser
    # parser << data -> parser
    # 
    # Feed data in to the parser and trigger callbacks.
    # 
    # Will raise HTTPTools::ParseError on error, unless a callback has been set
    # for the :error event, in which case the callback will recieve the error
    # insted.
    # 
    def concat(data)
      @buffer << data
      @state = send(@state)
      self
    end
    alias << concat
    
    # :call-seq: parser.env -> hash or nil
    # 
    # Returns a Rack compatible environment hash. Will return nil if called
    # before headers are complete.
    # 
    # "rack.input" is not supplied and must be added to make the environment
    # hash fully Rack compliant.
    # 
    def env
      return unless @header_complete
      env = PROTOTYPE_ENV.dup
      env[REQUEST_METHOD] = @request_method
      env[PATH_INFO] = @path_info
      env[QUERY_STRING] = @query_string
      @header.each do |key, value|
        upper_key = key.tr(LOWERCASE, UPPERCASE)
        upper_key = HTTP_ + upper_key unless NO_HTTP_.key?(upper_key)
        env[upper_key] = value
      end
      host, port = env[HTTP_HOST].split(COLON)
      env[SERVER_NAME] = host
      env[SERVER_PORT] = port || "80"
      @trailer.each {|k, val| env[HTTP_ + k.tr(LOWERCASE, UPPERCASE)] = val}
      env
    end
    
    # :call-seq: parser.finish -> parser
    # 
    # Used to notify the parser that the request has finished in a case where it
    # can not be determined by the request itself.
    # 
    # For example, when a server does not set a content length, and instead
    # relies on closing the connection to signify the body end.
    #   until parser.finished?
    #     begin
    #       parser << socket.sysread(1024 * 16)
    #     rescue EOFError
    #       parser.finish
    #       break
    #     end
    #   end
    # 
    # This method can not be used to interrupt parsing from within a callback.
    # 
    # Will raise HTTPTools::MessageIncompleteError if called too early, or
    # HTTPTools::EndOfMessageError if the message has already finished, unless
    # a callback has been set for the :error event, in which case the callback
    # will recieve the error insted.
    # 
    def finish
      if @state == :body_on_close
        @state = end_of_message
      elsif @state == :body_chunked && @header[CONNECTION] == CLOSE &&
        !@header[TRAILER] && @buffer.eos?
        @state = end_of_message
      elsif @state == :start && @buffer.string.length < 1
        raise EmptyMessageError.new("Message empty")
      else
        raise MessageIncompleteError.new("Message ended early")
      end
      self
    end
    
    # :call-seq: parser.finished? -> bool
    # 
    # Returns true when the parser has come to the end of the message, false
    # otherwise.
    # 
    # Some HTTP servers may not supply the necessary information in the response
    # to determine the end of the message (e.g., no content length) and insted
    # close the connection to signify the end of the message, see #finish for
    # how to deal with this.
    # 
    def finished?
      @state == :end_of_message
    end
    
    # :call-seq: parser.rest -> string
    # 
    # Returns unconsumed data in the parser's buffer.
    # 
    def rest
      @buffer.rest
    end
    
    # :call-seq: parser.reset -> parser
    # 
    # Reset the parser so it can be used to process a new request.
    # Callbacks/delegates will not be removed.
    # 
    def reset
      @state = :start
      @buffer.string.replace("")
      @buffer.reset
      @request_method = nil
      @path_info = nil
      @query_string = nil
      @request_uri = nil
      @version = nil
      @status_code = nil
      @header = {}
      @trailer = {}
      @last_key = nil
      @content_left = nil
      self
    end
    
    # :call-seq: parser.add_listener(event) {|arg1 [, arg2]| block} -> parser
    # parser.add_listener(event, proc) -> parser
    # parser.on(event) {|arg1 [, arg2]| block} -> parser
    # parser.on(event, proc) -> parser
    # 
    # Available events are :header, :stream, :trailer, :finish, and :error.
    # 
    # Adding a second callback for an event will overwite the existing callback
    # or delegate.
    # 
    # Events:
    # [header]     Called when headers are complete
    # 
    # [stream]     Supplied with one argument, the last chunk of body data fed
    #              in to the parser as a String, e.g. "<h1>Hello"
    # 
    # [trailer]    Called on the completion of the trailer, if present
    # 
    # [finish]     Called on completion of the entire message. Any unconsumed
    #              data (such as the start of the next message with keepalive)
    #              can be retrieved with #rest
    # 
    # [error]      Supplied with one argument, an error encountered while
    #              parsing as a HTTPTools::ParseError. If a listener isn't
    #              registered for this event, an exception will be raised when
    #              an error is encountered
    # 
    def add_listener(event, proc=nil, &block)
      instance_variable_set(:"@#{event}_callback", proc || block)
      self
    end
    alias on add_listener
    
    private
    def start
      @request_method = @buffer.scan(/[a-z]+ /i)
      if @request_method
        @request_method.chop!
        @request_method.upcase!
        uri
      elsif @buffer.check(/HTTP\//i)
        response_http_version
      elsif @buffer.check(/[a-z]*\Z/i)
        :start
      elsif @allow_html_without_header && @buffer.check(/\s*</i)
        skip_header
      else
        raise ParseError.new("Protocol or method not recognised")
      end
    end
    
    def uri
      @request_uri = @buffer.scan(/[a-z0-9;\/?:@&=+$,%_.!~*')(-]*(?=( |\r\n))/i)
      if @request_uri
        @path_info = @request_uri.dup
        @path_info.slice!(/^([a-z0-9+.-]*:\/\/)?[^\/]+/i)
        @query_string = @path_info.slice!(/\?[a-z0-9;\/?:@&=+$,%_.!~*')(-]*/i)
        @query_string ? @query_string.slice!(0) : @query_string = ""
        request_http_version
      elsif @buffer.check(/[a-z0-9;\/?:@&=+$,%_.!~*')(#-]+\Z/i)
        :uri
      else
        raise ParseError.new("URI or path not recognised")
      end
    end
    
    def request_http_version
      @version = @buffer.scan(/ HTTP\/[0-9]+\.[0-9x]+\r\n/i)
      if @version
        @version.strip!
        @version.upcase!
        key_or_newline
      elsif @buffer.skip(/\r\n/i)
        key_or_newline
      elsif @buffer.eos? ||
        @buffer.check(/ (H(T(T(P(\/(\d+(\.(\d+\r?)?)?)?)?)?)?)?)?\Z/i)
        :request_http_version
      else
        raise ParseError.new("Invalid version specifier")
      end
    end
    
    def response_http_version
      @version = @buffer.scan(/HTTP\/[0-9]+\.[0-9x]+ /i)
      if @version
        @version.chop!
        @version.upcase!
        status
      elsif @buffer.eos? ||
        @buffer.check(/H(T(T(P(\/(\d+(\.(\d+\r?)?)?)?)?)?)?)?\Z/i)
        :response_http_version
      else
        raise ParseError.new("Invalid version specifier")
      end
    end
    
    def skip_header
      @version = "0.0"
      @status_code = 200
      @message = ""
      @header_complete = true
      @header_callback.call if @header_callback
      body
    end
    
    def status
      status = @buffer.scan(/\d\d\d[^\x00-\x1f\x7f]*\r?\n/i)
      if status
        @status_code = status.slice!(0, 3).to_i
        @message = status.strip
        key_or_newline
      elsif @buffer.eos? ||
        @buffer.check(/\d(\d(\d( ([^\x00-\x1f\x7f]+\r?)?)?)?)?\Z/i)
        :status
      else
        raise ParseError.new("Invalid status line")
      end
    end
    
    def key_or_newline
      @last_key = @buffer.scan(/[ -9;-~]+: /i)
      if @last_key
        @last_key.chomp!(KEY_TERMINATOR)
        value
      elsif @buffer.skip(/\r?\n/i)
        @header_complete = true
        @header_callback.call if @header_callback
        body
      elsif @buffer.eos? || @buffer.check(/([ -9;-~]+:?|\r)\Z/i)
        :key_or_newline
      elsif @last_key = @buffer.scan(/[ -9;-~]+:(?=[^ ])/i)
        @last_key.chomp!(COLON)
        value
      else
        skip_bad_header
      end
    end
    
    def skip_bad_header
      if @buffer.skip(/[^\x00\n\x7f]*\n/)
        key_or_newline
      elsif @buffer.check(/[^\x00\n\x7f]+\Z/)
        :skip_bad_header
      else
        raise ParseError.new("Illegal character in field name")
      end
    end
    
    def value
      value = @buffer.scan(/[^\x00\n\x7f]*\n/i)
      if value
        value.chop!
        if ARRAY_VALUE_HEADERS.key?(@last_key)
          @header.fetch(@last_key) {@header[@last_key] = []}.push(value)
        else
          @header[@last_key] = value
        end
        key_or_newline
      elsif @buffer.eos? || @buffer.check(/[^\x00\n\x7f]+\Z/i)
        :value
      else
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def body
      if @request_method &&
        !(@header.key?(CONTENT_LENGTH) || @header.key?(TRANSFER_ENCODING)) ||
        NO_BODY.key?(@status_code) || @force_no_body
        end_of_message
      else
        length = @header[CONTENT_LENGTH]
        if length
          @content_left = length.to_i
          body_with_length
        elsif @header[TRANSFER_ENCODING] == CHUNKED
          body_chunked
        else
          body_on_close
        end
      end
    end
    
    def body_with_length
      if !@buffer.eos?
        chunk = @buffer.string.slice(@buffer.pos, @content_left)
        @stream_callback.call(chunk) if @stream_callback
        chunk_length = chunk.length
        @buffer.pos += chunk_length
        @content_left -= chunk_length
        if @content_left < 1
          end_of_message
        else
          :body_with_length
        end
      elsif @content_left < 1 # zero length body
        @stream_callback.call("") if @stream_callback
        end_of_message
      else
        :body_with_length
      end
    end
    
    def body_chunked
      decoded, remainder = transfer_encoding_chunked_decode(nil, @buffer)
      if decoded
        @stream_callback.call(decoded) if @stream_callback
      end
      if remainder
        :body_chunked
      else
        if @header[TRAILER] || @force_trailer
          trailer_key_or_newline
        else
          end_of_message
        end
      end
    end
    
    def body_on_close
      chunk = @buffer.rest
      @buffer.terminate
      @stream_callback.call(chunk) if @stream_callback
      :body_on_close
    end
    
    def trailer_key_or_newline
      if @last_key = @buffer.scan(/[ -9;-~]+: /i)
        @last_key.chomp!(KEY_TERMINATOR)
        trailer_value
      elsif @buffer.skip(/\r?\n/i)
        @trailer_callback.call if @trailer_callback
        end_of_message
      elsif @buffer.eos? || @buffer.check(/([ -9;-~]+:?|\r)\Z/i)
        :trailer_key_or_newline
      elsif @last_key = @buffer.scan(/[ -9;-~]+:(?=[^ ])/i)
        @last_key.chomp!(COLON)
        trailer_value
      else
        raise ParseError.new("Illegal character in field name")
      end
    end
    
    def trailer_value
      value = @buffer.scan(/[^\000\n\177]+\n/i)
      if value
        value.chop!
        @trailer[@last_key] = value
        trailer_key_or_newline
      elsif @buffer.eos? || @buffer.check(/[^\x00\n\x7f]+\Z/i)
        :trailer_value
      else
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def end_of_message
      raise EndOfMessageError.new("Message ended") if @state == :end_of_message
      @finish_callback.call if @finish_callback
      :end_of_message
    end
    
    def raise(*args)
      @state = :error
      super unless @error_callback
      @error_callback.call(args.first)
      :error
    end
    alias error raise
    
  end
end