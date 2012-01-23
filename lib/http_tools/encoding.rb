# encoding: ASCII-8BIT
require 'strscan'

module HTTPTools
  
  # HTTPTools::Encoding provides methods to deal with several HTTP related
  # encodings including url, www-form, and chunked transfer encoding. It can be
  # used as a mixin or class methods on HTTPTools::Encoding.
  # 
  module Encoding
    # :stopdoc:
    HEX_BIG_ENDIAN_2_BYTES = "H2".freeze
    HEX_BIG_ENDIAN_REPEATING = "H*".freeze
    PERCENT = "%".freeze
    PLUS = "+".freeze
    SPACE = " ".freeze
    AMPERSAND = "&".freeze
    EQUALS = "=".freeze
    # :startdoc:
    
    module_function
    
    # :call-seq: Encoding.url_encode(string) -> encoded_string
    # 
    # URL encode a string, eg "le café" becomes "le+caf%c3%a9"
    # 
    def url_encode(string)
      string.gsub(/[^a-z0-9._~-]+/i) do |match|
        length = match.respond_to?(:bytesize) ? match.bytesize : match.length
        PERCENT + match.unpack(HEX_BIG_ENDIAN_2_BYTES * length).join(PERCENT)
      end
    end
    
    # :call-seq: Encoding.url_decode(encoded_string) -> string
    # 
    # URL decode a string, eg "le+caf%c3%a9" becomes "le café"
    # 
    def url_decode(string)
      string.tr(PLUS, SPACE).gsub(/(%[0-9a-f]{2})+/i) do |match|
        r = [match.delete(PERCENT)].pack(HEX_BIG_ENDIAN_REPEATING)
        r.respond_to?(:force_encoding) ? r.force_encoding(string.encoding) : r
      end
    end
    
    # :call-seq: Encoding.www_form_encode(hash) -> string
    # 
    # Takes a Hash and converts it to a String as if it was a HTML form being
    # submitted, eg
    # {"query" => "fish", "lang" => "en"} becomes "query=fish&lang=en"
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
    # eg "lang=en&query=fish" becomes {"lang" => "en", "query" => "fish"}
    # 
    # Multiple key value pairs with the same key will become a single key with
    # an array value, eg "lang=en&lang=fr" becomes {"lang" => ["en", "fr"]}
    #
    def www_form_decode(string)
      out = {}
      string.split(AMPERSAND).each do |key_value|
        key, value = key_value.split(EQUALS)
        key, value = url_decode(key), url_decode(value)
        if out.key?(key)
          out[key] = [*out[key]].push(value)
        else
          out[key] = value
        end
      end
      out
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
      if string && (length = string.length) > 0
        "#{length.to_s(16)}\r\n#{string}\r\n"
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
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)
    #   #=> ["foobar", nil]
    # 
    # Decoding a partial response will return an array of the response decoded
    # so far, and the remainder of the encoded string.
    # Example
    #   encoded_string = "3\r\nfoo\r\n3\r\nba"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)
    #   #=> ["foo", "3\r\nba"]
    # 
    # If the chunks are complete, but there is no empty terminating chunk, the
    # second element in the array will be an empty string.
    #   encoded_string = "3\r\nfoo\r\n3\r\nbar"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)
    #   #=> ["foobar", ""]
    # 
    # If nothing can be decoded the first element in the array will be nil and
    # the second the remainder
    #   encoded_string = "3\r\nfo"
    #   Encoding.transfer_encoding_chunked_decode(encoded_string)
    #   #=> [nil, "3\r\nfo"]
    # 
    # Example use:
    #   include Encoding
    #   decoded = ""
    #   remainder = ""
    #   while remainder
    #     remainder << get_data
    #     chunk, remainder = transfer_encoding_chunked_decode(remainder)
    #     decoded << chunk if chunk
    #   end
    # 
    def transfer_encoding_chunked_decode(str, scanner=StringScanner.new(str))
      decoded = ""
      
      remainder = while true
        start_pos = scanner.pos
        hex_chunk_length = scanner.scan(/[0-9a-f]+ *\r?\n/i)
        break scanner.rest unless hex_chunk_length
        
        chunk_length = hex_chunk_length.to_i(16)
        break nil if chunk_length == 0
        
        begin
          chunk = scanner.rest.slice(0, chunk_length)
          scanner.pos += chunk_length
          if chunk && scanner.skip(/\r?\n/i)
            decoded << chunk
          else
            scanner.pos = start_pos
            break scanner.rest
          end
        rescue RangeError
          scanner.pos = start_pos
          break scanner.rest
        end
      end
      
      [(decoded if decoded.length > 0), remainder]
    end
    
  end
end