module HTTPTools
  class Error < StandardError; end
  class ParseError < Error; end
  class EndOfMessageError < ParseError; end
  class MessageIncompleteError < EndOfMessageError; end
  class EmptyMessageError < MessageIncompleteError; end
end