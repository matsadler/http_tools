# encoding: ASCII-8BIT
require 'strscan'

module HTTPTools
  class MultipartFormDataParser
    ONE_MB = 1024 * 1024
    COLON = ":".freeze
    SPACE = " ".freeze
    KEY_TERMINATOR = ": ".freeze
    
    attr_reader :state # :nodoc:
    
    def initialize(boundry)
      reset(boundry)
    end
    
    def call(data)
      @buffer << data
      @state = send(@state)
      if @buffer.string.length > ONE_MB
        @buffer.string.slice!(0, @buffer.pos)
        @buffer.pos = 0
      end
      self
    end
    
    def to_proc
      Proc.new {|data| call(data)}
    end
    
    def add_listener(event, proc=nil, &block)
      instance_variable_set(:"@#{event}_callback", proc || block)
      self
    end
    alias on add_listener
    
    def reset(boundry)
      chars = boundry.chars.to_a.concat(%W{-\r\n}).uniq
      @non_boundry_chars = Regexp.new("[^#{chars.map{|c|Regexp.escape c}.join("")}]+")
      @initial_boundry = Regexp.new(Regexp.escape("--" + boundry))
      @boundry = Regexp.new("\r?\n--#{Regexp.escape(boundry)}")
      @boundry_length = boundry.length + 2
      @buffer = StringScanner.new("")
      @state = :start
      @header = {}
    end
    
    private
    def start
      if @buffer.scan(@initial_boundry)
        newline_before_headers
      elsif @buffer.rest_size > @boundry_length
        raise ParseError.new("Expected boundry")
      else
        :start
      end
    end
    
    def newline_before_headers
      if @buffer.scan(/\r?\n/)
        key_or_newline
      elsif @buffer.rest_size > @boundry_length
        raise ParseError.new("Expected newline")
      else
        :newline_before_headers
      end
    end
    
    def key_or_newline
      @last_key = @buffer.scan(/[ -9;-~]+: /)
      if @last_key
        @last_key.chomp!(KEY_TERMINATOR)
        value
      elsif @buffer.skip(/\r?\n/)
        @header_complete = true
        @header_callback.call(@header) if @header_callback
        data
      elsif @buffer.eos? || @buffer.check(/([ -9;-~]+:?|\r)\Z/i)
        :key_or_newline
      elsif @last_key = @buffer.scan(/[ -9;-~]+:(?=[^ ])/i)
        @last_key.chomp!(COLON)
        value
      else
        @buffer.skip(/[ -9;-~]+/i)
        raise ParseError.new("Illegal character in field name")
      end
    end
    
    def value
      value = @buffer.scan(/[^\x00\n\x7f]*\n/i)
      if value
        value.strip!
        if @header.key?(@last_key)
          @header[@last_key] << "\n#{value}"
        else
          @header[@last_key.freeze] = value
        end
        value_extention
      elsif @buffer.eos? || @buffer.check(/[^\x00\n\x7f]+\Z/i)
        :value
      else
        @buffer.skip(/[^\x00\n\x7f]+/i)
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def value_extention
      if @buffer.check(/[^ \t]/i)
        key_or_newline
      elsif value_extra = @buffer.scan(/[ \t]+[^\x00\n\x7f]*\n/i)
        value_extra.sub!(/^[ \t]+/i, SPACE)
        value_extra.chop!
        (@header[@last_key] << value_extra).strip!
        value_extention
      elsif @buffer.eos? || @buffer.check(/[ \t]+[^\x00\n\x7f]*\Z/i)
        :value_extention
      else
        @buffer.skip(/[ \t]+[^\x00\n\x7f]*/i)
        raise ParseError.new("Illegal character in field body")
      end
    end
    
    def data
      if chunk = @buffer.scan_until(@boundry)
        chunk.slice!(-@boundry_length, @boundry_length)
        chunk.chomp!
        @stream_callback.call(chunk) if @stream_callback
        @stream_finish_callback.call if @stream_finish_callback
        after_boundry
      elsif chunk = @buffer.scan(@non_boundry_chars)
        @stream_callback.call(chunk) if @stream_callback
        :data
      elsif @buffer.rest_size > (@boundry_length * 2)
        chunk = @buffer.string[@buffer.pos, @boundry_length]
        @stream_callback.call(chunk) if @stream_callback
        @buffer.pos += @boundry_length
        :data
      else
        :data
      end
    end
    
    def after_boundry
      if @buffer.skip(/\r?\n/)
        @header = {}
        key_or_newline
      elsif @buffer.skip(/--/)
        end_of_message
      elsif @buffer.rest_size > 2
        raise ParseError.new("Expected newline or end")
      else
        :after_boundry
      end
    end
    
    def end_of_message
      raise EndOfMessageError.new("Message ended") if @state == :end_of_message
      @finish_callback.call if @finish_callback
      :end_of_message
    end
    
  end
end
