module HTTPTools
  class ParseError < StandardError; end
  class EndOfMessageError < ParseError; end
  class MessageIncompleteError < EndOfMessageError; end
  class EmptyMessageError < MessageIncompleteError; end
end