# encoding: ASCII-8BIT
base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class URLEncodingTest < Test::Unit::TestCase
  
  def test_encode
    result = HTTPTools::Encoding.url_encode("[A] (test/example)=<string>?")
    
    assert_equal("%5bA%5d%20%28test%2fexample%29%3d%3cstring%3e%3f", result)
  end
  
  def test_decode
    result = HTTPTools::Encoding.url_decode("%5bA%5d%20%28test%2fexample%29%3d%3cstring%3e%3f")
    
    assert_equal("[A] (test/example)=<string>?", result)
  end
  
  def test_encode_allowed_characters
    result = HTTPTools::Encoding.url_encode("A_test-string~1.")
    
    assert_equal("A_test-string~1.", result)
  end
  
  def test_encode_latin_capital_letter_a_with_grave
    result = HTTPTools::Encoding.url_encode("À")
    
    assert_equal("%c3%80", result)
  end
  
  def test_decode_latin_capital_letter_a_with_grave
    result = HTTPTools::Encoding.url_decode("%C3%80")
    
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == "macruby"
      # work around macruby not respecting the coding comment
      assert_equal("À".force_encoding("ASCII-8BIT"), result)
    else
      assert_equal("À", result)
    end
  end
  
end
