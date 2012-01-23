# encoding: ASCII-8BIT
require_base = File.expand_path('../http_tools', __FILE__)
require require_base + '/encoding'
require require_base + '/parser'
require require_base + '/builder'

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
    :multi_status => 207,
    :im_used => 226,
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
    :im_a_teapot => 418,
    :unprocessable_entity => 422,
    :locked => 423,
    :failed_dependency => 424,
    :upgrade_required => 426,
    :internal_server_error => 500,
    :not_implemented => 501,
    :bad_gateway => 502,
    :service_unavailable => 503,
    :gateway_timeout => 504,
    :http_version_not_supported => 505,
    :variant_also_negotiates => 506,
    :insufficient_storage => 507}.freeze
  
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
    207 => "Multi-Status",
    226 => "IM Used",
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
    418 => "I'm a teapot",
    422 => "Unprocessable Entity",
    423 => "Locked",
    424 => "Failed Dependency",
    426 => "Upgrade Required",
    500 => "Internal Server Error",
    501 => "Not Implemented",
    502 => "Bad Gateway",
    503 => "Service Unavailable",
    504 => "Gateway Timeout",
    505 => "HTTP Version Not Supported",
    506 => "Variant Also Negotiates",
    507 => "Insufficient Storage"}.freeze
  STATUS_DESCRIPTIONS.values.each {|val| val.freeze}
  
  # :stopdoc: hide from rdoc as it makes a mess
  STATUS_LINES = {}
  STATUS_CODES.each do |name, code|
    line = "#{code} #{STATUS_DESCRIPTIONS[code]}"
    STATUS_LINES[name] = line
    STATUS_LINES[code] = line
  end
  STATUS_LINES.freeze
  # :startdoc:
  
  METHODS = %W{GET POST HEAD PUT DELETE OPTIONS TRACE CONNECT}.freeze
  
  # presence of key tested, not value
  NO_BODY = {204 => true, 205 => true, 304 => true}
  100.upto(199) {|status_code| NO_BODY[status_code] = true}
  NO_BODY.freeze
  
  Error = Class.new(StandardError)
  ParseError = Class.new(Error)
  EndOfMessageError = Class.new(ParseError)
  MessageIncompleteError = Class.new(EndOfMessageError)
  EmptyMessageError = Class.new(MessageIncompleteError)
end
