module HTTPTools
  class ParseError < StandardError; end
  class EndOfMessageError < ParseError; end
  class MessageIncompleteError < EndOfMessageError; end
end