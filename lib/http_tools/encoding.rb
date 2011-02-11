require 'strscan'

module HTTPTools
  
  # HTTPTools::Encoding provides methods to deal with several HTTP related
  # encodings including url, www-form, and chunked transfer encoding. It can be
  # used as a mixin or class methods on HTTPTools::Encoding.
  # 
  module Encoding
    HEX_BIG_ENDIAN_2_BYTES = "H2".freeze
    HEX_BIG_ENDIAN_REPEATING = "H*".freeze
    PERCENT = "%".freeze
    PLUS = "+".freeze
    AMPERSAND = "&".freeze
    EQUALS = "=".freeze
    CHUNK_FORMAT = "%x\r\n%s\r\n".freeze
    
    module_function
    
    # :call-seq: Encoding.url_encode(string) -> encoded_string
    # 
    # URL encode a string, eg "le café" becomes "le+caf%c3%a9"
    # 
    def url_encode(string)
      string.gsub(/[^a-zA-Z0-9._~-]+/) do |match|
        length = match.respond_to?(:bytesize) ? match.bytesize : match.length
        PERCENT + match.unpack(HEX_BIG_ENDIAN_2_BYTES * length).join(PERCENT)
      end
    end
    
    # :call-seq: Encoding.url_decode(encoded_string) -> string
    # 
    # URL decode a string, eg "le+caf%c3%a9" becomes "le café"
    # 
    def url_decode(string)
      string.tr(PLUS, SPACE).gsub(/(%[0-9a-fA-F]{2})+/) do |match|
        r = [match.delete(PERCENT)].pack(HEX_BIG_ENDIAN_REPEATING)
        r.respond_to?(:force_encoding) ? r.force_encoding(string.encoding) : r
      end
    end
    
    # :call-seq: Encoding.www_form_encode(hash) -> string
    # 
    # Takes a Hash and converts it to a String as if it was a HTML form being
    # submitted, eg
    # {"query" => "fish", "lang" => "en"} becomes "lang=en&query=fish"
    # 
    # To get multiple key value pairs with the same key use an array as the
    # value, eg
    # {"lang" => ["en", "fr"]} become "lang=en&lang=fr"
    # 
    def www_form_encode(hash)
      hash.map do |key, value|
        if value.respond_to?(:map) && !value.is_a?(String)
          value.map {|val| www_form_encode(key => val.to_s)}.join(AMPERSAND)
        else
          url_encode(key.to_s) << EQUALS << url_encode(value.to_s)
        end
      end.join(AMPERSAND)
    end
    
    # :call-seq: Encoding.www_form_decode(string) -> hash
    # 
    # Takes a String resulting from a HTML form being submitted, and converts it
    # to a hash,
    # eg "lang=en&query=fish" becomes {"query" => "fish", "lang" => "en"}
    # 
    # Multiple key value pairs with the same key will become a single key with
    # an array value, eg "lang=en&lang=fr" becomes {"lang" => ["en", "fr"]}
    #
    def www_form_decode(string)
      string.split(AMPERSAND).inject({}) do |memo, key_value|
        key, value = key_value.split(EQUALS)
        key, value = url_decode(key), url_decode(value)
        if memo.key?(key)
          memo.merge(key => [*memo[key]].push(value))
        else
          memo.merge(key => value)
        end
      end
    end
    
    # :call-seq:
    # Encoding.transfer_encoding_chunked_encode(string) -> encoded_string
    # 
    # Returns string as a 'chunked' transfer encoding encoded string, suitable
    # for a streaming response from a HTTP server, eg
    # "foo" becomes "3\r\nfoo\r\n"
    #
    # chunked responses should be terminted with a empty chunk, eg "0\r\n",
    # passing an empty string or nil will generate the empty chunk.
    # 
    def transfer_encoding_chunked_encode(string)
      if string && string.length > 0
        sprintf(CHUNK_FORMAT, string.length, string)
      else
        "0\r\n"
      end
    end
    
    # :call-seq:
    # Encoding.transfer_encoding_chunked_decode(encoded_string) -> array
    # 
    # Decoding a complete chunked response will return an array containing
    # the decoded response and nil.
    # Example:
    #   encoded_string = "3\r\nfoo\r\n3\r\nbar\r\n0\r\n"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)\
    # => ["foobar", nil]
    # 
    # Decoding a partial response will return an array of the response decoded
    # so far, and the remainder of the encoded string.
    # Example
    #   encoded_string = "3\r\nfoo\r\n3\r\nba"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)\
    # => ["foo", "3\r\nba"]
    # 
    # If the chunks are complete, but there is no empty terminating chunk, the
    # second element in the array will be an empty string.
    #   encoded_string = "3\r\nfoo\r\n3\r\nbar"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)\
    # => ["foobar", ""]
    # 
    # If nothing can be decoded the first element in the array will be an empty
    # string and the second the remainder
    #   encoded_string = "3\r\nfo"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)\
    # => ["", "3\r\nfo"]
    # 
    # Example use:
    #   include Encoding
    #   decoded = ""
    #   remainder = ""
    #   while remainder
    #     remainder << get_data
    #     chunk, remainder = transfer_encoding_chunked_decode(remainder)
    #     decoded << chunk
    #   end
    # 
    def transfer_encoding_chunked_decode(scanner)
      unless scanner.is_a?(StringScanner)
        scanner = StringScanner.new(scanner.dup)
      end
      hex_chunk_length = scanner.scan(/[0-9a-fA-F]+ *\r?\n/)
      return [nil, scanner.string] unless hex_chunk_length
      
      chunk_length = hex_chunk_length.to_i(16)
      return [nil, nil] if chunk_length == 0
      
      chunk = scanner.rest.slice(0, chunk_length)
      begin
        scanner.pos += chunk_length
        separator = scanner.scan(/\n|\r\n/)
      rescue RangeError
      end
      
      if separator && chunk.length == chunk_length
        scanner.string.replace(scanner.rest)
        scanner.reset
        rest, remainder = transfer_encoding_chunked_decode(scanner)
        chunk << rest if rest
        [chunk, remainder]
      else
        [nil, scanner.string]
      end
    end
    
  end
end