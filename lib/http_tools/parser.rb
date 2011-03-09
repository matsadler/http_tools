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
  #   parser.on(:status) {|status, message| puts "#{status} #{message}"}
  #   parser.on(:headers) {|headers| puts headers.inspect}
  #   parser.on(:body) {|body| puts body}
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
    EVENTS = ["method", "path", "uri", "fragment", "version", "status", "key",
      "value", "headers", "stream", "body", "trailers", "finished",
      "error"].map {|event| event.freeze}.freeze
    
    attr_reader :state # :nodoc:
    
    # Force parser to expect and parse a trailer when Trailer header missing.
    attr_accessor :force_trailer
    
    # Skip parsing the body, e.g. with the response to a HEAD request.
    attr_accessor :force_no_body
    
    # :call-seq: Parser.new(delegate=nil) -> parser
    # 
    # Create a new HTTPTools::Parser.
    # 
    # delegate is an object that will recieve callbacks for events during
    # parsing. The delegate's methods should be named on_[event name], e.g.
    # on_status, on_body, etc. See #add_listener for more.
    # 
    # Example:
    #   class ExampleDelegate
    #     def on_status(status, message)
    #       puts "#{status} #{message}"
    #     end
    #   end
    #   parser = HTTPTools::Parser.new(ExampleDelegate.new)
    # 
    # If a callback is set for an event, it will take precedence over the
    # delegate for that event.
    # 
    def initialize(delegate=nil)
      @state = :start
      @buffer = StringScanner.new("")
      @buffer_backup_reference = @buffer
      @status = nil
      @headers = {}
      @last_key = nil
      @content_left = nil
      @body = nil
      if delegate
        EVENTS.each do |event|
          id = "on_#{event}"
          add_listener(event, delegate.method(id)) if delegate.respond_to?(id)
        end
      end
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
        @body_callback.call(@body) if @body_callback
        @state = end_of_message
      elsif @state == :body_chunked && @headers[CONNECTION] == CLOSE &&
        !@headers[TRAILER] && @buffer.eos?
        @body_callback.call(@body) if @body_callback
        @state = end_of_message
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
    
    # :call-seq: parser.reset -> parser
    # 
    # Reset the parser so it can be used to process a new request.
    # Callbacks/delegates will not be removed.
    # 
    def reset
      @state = :start
      @buffer = @buffer_backup_reference
      @buffer.string.replace("")
      @buffer.reset
      # @status = nil
      @headers = {}
      @trailer = {}
      # @last_key = nil
      # @content_left = nil
      @body = nil
      self
    end
    
    # :call-seq: parser.add_listener(event) {|arg1 [, arg2]| block} -> parser
    # parser.add_listener(event, proc) -> parser
    # parser.on(event) {|arg1 [, arg2]| block} -> parser
    # parser.on(event, proc) -> parser
    # 
    # Available events are :method, :path, :version, :status, :headers, :stream,
    # :body, and :error.
    # 
    # Adding a second callback for an event will overwite the existing callback
    # or delegate.
    # 
    # Events:
    # [method]     Supplied with one argument, the HTTP method as a String,
    #              e.g. "GET"
    # 
    # [path]       Supplied with two arguments, the request path as a String,
    #              e.g. "/example.html", and the query string as a String,
    #              e.g. "query=foo"
    #              (this callback is only called if the request uri is a path)
    # 
    # [uri]        Supplied with one argument, the request uri as a String,
    #              e.g. "/example.html?query=foo"
    # 
    # [fragment]   Supplied with one argument, the fragment from the request
    #              uri, if present
    # 
    # [version]    Supplied with one argument, the HTTP version as a String,
    #              e.g. "1.1"
    # 
    # [status]     Supplied with two arguments, the HTTP status code as a
    #              Numeric, e.g. 200, and the HTTP status message as a String,
    #              e.g. "OK"
    # 
    # [headers]    Supplied with one argument, the message headers as a Hash,
    #              e.g. {"Content-Length" => "20"}
    # 
    # [stream]     Supplied with one argument, the last chunk of body data fed
    #              in to the parser as a String, e.g. "<h1>Hello"
    # 
    # [body]       Supplied with one argument, the message body as a String,
    #              e.g. "<h1>Hello world</h1>"
    # 
    # [trailer]    Supplied with one argument, the message trailer as a Hash
    # 
    # [finished]   Supplied with one argument, any data left in the parser's
    #              buffer after the end of the HTTP message (likely nil, but
    #              possibly the start of the next message)
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
      method = @buffer.scan(/[a-z]+ /i)
      if method
        if @method_callback
          method.chop!
          method.upcase!
          @method_callback.call(method)
        end
        uri
      elsif @buffer.skip(/HTTP\//i)
        response_http_version
      elsif @buffer.check(/[a-z]+\Z/i)
        :start
      else
        raise ParseError.new("Protocol or method not recognised")
      end
    end
    
    def uri
      uri = @buffer.scan(/[a-z0-9;\/?:@&=+$,%_.!~*')(#-]*(?=( |\r\n))/i)
      if uri
        fragment = uri.slice!(/#[a-z0-9;\/?:@&=+$,%_.!~*')(-]+\Z/i)
        if @path_callback && uri =~ /^\//i
          path = uri.dup
          query = path.slice!(/\?[a-z0-9;\/?:@&=+$,%_.!~*')(-]*/i)
          query.slice!(0) if query
          @path_callback.call(path, query)
        end
        @uri_callback.call(uri) if @uri_callback
        if fragment && @fragment_callback
          fragment.slice!(0)
          @fragment_callback.call(fragment)
        end
        space_before_http
      elsif @buffer.check(/[a-z0-9;\/?:@&=+$,%_.!~*')(#-]+\Z/i)
        :uri
      else
        raise ParseError.new("URI or path not recognised")
      end
    end
    
    def space_before_http
      if @buffer.skip(/ /i)
        http
      elsif @buffer.skip(/\r\n/i)
        key_or_newline
      end
    end
    
    def http
      if @buffer.skip(/HTTP\//i)
        request_http_version
      elsif @buffer.eos? || @buffer.check(/H(T(T(P\/?)?)?)?\Z/i)
        :http
      else
        raise ParseError.new("Protocol not recognised")
      end
    end
    
    def request_http_version
      version = @buffer.scan(/[0-9]+\.[0-9]+\r\n/i)
      if version
        if @version_callback
          version.chop!
          @version_callback.call(version)
        end
        key_or_newline
      elsif @buffer.eos? || @buffer.check(/\d+(\.(\d+\r?)?)?\Z/i)
        :request_http_version
      else
        raise ParseError.new("Invalid version specifier")
      end
    end
    
    def response_http_version
      version = @buffer.scan(/[0-9]+\.[0-9]+ /i)
      if version
        if @version_callback
          version.chop!
          @version_callback.call(version)
        end
        status
      elsif @buffer.eos? || @buffer.check(/\d+(\.(\d+)?)?\Z/i)
        :response_http_version
      else
        raise ParseError.new("Invalid version specifier")
      end
    end
    
    def status
      status = @buffer.scan(/\d\d\d[^\000-\037\177]*\r?\n/i)
      if status
        @status = status.slice!(0, 3).to_i
        @status_callback.call(@status, status.strip) if @status_callback
        key_or_newline
      elsif @buffer.eos? ||
        @buffer.check(/\d(\d(\d( ([^\000-\037\177]+\r?)?)?)?)?\Z/i)
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
      elsif @buffer.skip(/\n|\r\n/i)
        @headers_callback.call(@headers) if @headers_callback
        body
      elsif @buffer.eos? || @buffer.check(/([ -9;-~]+:?|\r)\Z/i)
        :key_or_newline
      elsif @last_key = @buffer.scan(/[ -9;-~]+:(?=[^ ])/i)
        @last_key.chomp!(COLON)
        value
      else
        raise ParseError.new("Illegal character in field name")
      end
    end
    
    def value
      value = @buffer.scan(/[^\000\r\n\177]*\r?\n/i)
      if value
        value.chop!
        if ARRAY_VALUE_HEADERS[@last_key]
          @headers.fetch(@last_key) {@headers[@last_key] = []}.push(value)
        else
          @headers[@last_key] = value
        end
        key_or_newline
      elsif @buffer.eos? || @buffer.check(/[^\000\r\n\177]+\r?\Z/i)
        :value
      else
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def body
      if @force_no_body || NO_BODY[@status]
        end_of_message
      else
        @body = "" if @body_callback
        length = @headers[CONTENT_LENGTH]
        if length
          @content_left = length.to_i
          body_with_length
        elsif @headers[TRANSFER_ENCODING] == CHUNKED
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
        @body << chunk if @body_callback
        chunk_length = chunk.length
        @buffer.pos += chunk_length
        @content_left -= chunk_length
        if @content_left < 1
          @body_callback.call(@body) if @body_callback
          end_of_message
        else
          :body_with_length
        end
      elsif @content_left < 1 # zero length body
        @stream_callback.call("") if @stream_callback
        @body_callback.call("") if @body_callback
        end_of_message
      else
        :body_with_length
      end
    end
    
    def body_chunked
      decoded, remainder = transfer_encoding_chunked_decode(nil, @buffer)
      if decoded
        @stream_callback.call(decoded) if @stream_callback
        @body << decoded if @body_callback
      end
      if remainder
        :body_chunked
      else
        @body_callback.call(@body) if @body_callback
        if @headers[TRAILER] || @force_trailer
          @trailer = {}
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
      @body << chunk if @body_callback
      :body_on_close
    end
    
    def trailer_key_or_newline
      if @last_key = @buffer.scan(/[ -9;-~]+: /i)
        @last_key.chomp!(KEY_TERMINATOR)
        trailer_value
      elsif @buffer.skip(/\n|\r\n/i)
        @trailer_callback.call(@trailer) if @trailer_callback
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
      value = @buffer.scan(/[^\000\r\n\177]+\r?\n/i)
      if value
        value.chop!
        @trailer[@last_key] = value
        trailer_key_or_newline
      elsif @buffer.eos? || @buffer.check(/[^\000\r\n\177]+\r?\Z/i)
        :trailer_value
      else
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def end_of_message
      raise EndOfMessageError.new("Message ended") if @state == :end_of_message
      remainder = @buffer.respond_to?(:rest) ? @buffer.rest : @buffer
      if @finished_callback
        @finished_callback.call((remainder if remainder.length > 0))
      end
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