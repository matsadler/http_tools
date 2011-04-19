module HTTPTools
  STATUS_CODES = {
    :continue => 100,
    :switching_protocols => 101,
    :ok => 200,
    :created => 201,
    :accepted => 202,
    :non_authoritative_information => 203,
    :no_content => 204,
    :reset_content => 205,
    :partial_content => 206,
    :multiple_choices => 300,
    :moved_permanently => 301,
    :found => 302,
    :see_other => 303,
    :not_modified => 304,
    :use_proxy => 305,
    :temporary_redirect => 307,
    :bad_request => 400,
    :unauthorized => 401,
    :payment_required => 402,
    :forbidden => 403,
    :not_found => 404,
    :method_not_allowed => 405,
    :not_acceptable => 406,
    :proxy_authentication_required => 407,
    :request_timeout => 408,
    :conflict => 409,
    :gone => 410,
    :length_required => 411,
    :precondition_failed => 412,
    :request_entity_too_large => 413,
    :request_uri_too_long => 414,
    :unsupported_media_type => 415,
    :requested_range_not_satisfiable => 416,
    :expectation_failed => 417,
    :internal_server_error => 500,
    :not_implemented => 501,
    :bad_gateway => 502,
    :service_unavailable => 503,
    :gateway_timeout => 504,
    :http_version_not_supported => 505}.freeze
  
  STATUS_DESCRIPTIONS = {
    100 => "Continue",
    101 => "Switching Protocols",
    200 => "OK",
    201 => "Created",
    202 => "Accepted",
    203 => "Non-Authoritative Information",
    204 => "No Content",
    205 => "Reset Content",
    206 => "Partial Content",
    300 => "Multiple Choices",
    301 => "Moved Permanently",
    302 => "Found",
    303 => "See Other",
    304 => "Not Modified",
    305 => "Use Proxy",
    307 => "Temporary Redirect",
    400 => "Bad Request",
    401 => "Unauthorized",
    402 => "Payment Required",
    403 => "Forbidden",
    404 => "Not Found",
    405 => "Method Not Allowed",
    406 => "Not Acceptable",
    407 => "Proxy Authentication Required",
    408 => "Request Timeout",
    409 => "Conflict",
    410 => "Gone",
    411 => "Length Required",
    412 => "Precondition Failed",
    413 => "Request Entity Too Large",
    414 => "Request-URI Too Long",
    415 => "Unsupported Media Type",
    416 => "Requested Range Not Satisfiable",
    417 => "Expectation Failed",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported"}.freeze
  STATUS_DESCRIPTIONS.values.each {|val| val.freeze}
  
  STATUS_LINES = Hash.new do |hash, key|
    code = if key.kind_of?(Integer) then key else STATUS_CODES[key] end
    description = STATUS_DESCRIPTIONS[code]
    hash[key] = "#{code} #{description}"
  end
  
  METHODS = %W{GET POST HEAD PUT DELETE OPTIONS TRACE CONNECT}.freeze
  
  NO_BODY = {204 => true, 304 => true} # presence of key tested, not value
  100.upto(199) {|status_code| NO_BODY[status_code] = true}
  NO_BODY.freeze
  
  ARRAY_VALUE_HEADERS = {"Set-Cookie" => true} # presence of key tested, not val
  
  require_base = File.dirname(__FILE__) + '/http_tools/'
  autoload :Encoding, require_base + 'encoding'
  autoload :Parser, require_base + 'parser'
  autoload :Builder, require_base + 'builder'
  autoload :ParseError, require_base + 'errors'
  autoload :EndOfMessageError, require_base + 'errors'
  autoload :MessageIncompleteError, require_base + 'errors'
  autoload :EmptyMessageError, require_base + 'errors'
  
end