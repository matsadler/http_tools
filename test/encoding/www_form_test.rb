base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class WWWFormTest < Test::Unit::TestCase
  
  def test_encode
    result = HTTPTools::Encoding.www_form_encode("foo" => "bar", "baz" => "qux")
    
    # may fail under Ruby < 1.9 because of the unpredictable ordering of Hash
    assert_equal("foo=bar&baz=qux", result)
  end
  
  def test_encode_with_array
    result = HTTPTools::Encoding.www_form_encode("lang" => ["en", "fr"], "q" => ["foo", "bar"])
    
    # may fail under Ruby < 1.9 because of the unpredictable ordering of Hash
    assert_equal("lang=en&lang=fr&q=foo&q=bar", result)
  end
  
  def test_decode
    result = HTTPTools::Encoding.www_form_decode("foo=bar&baz=qux")
    
    assert_equal({"foo" => "bar", "baz" => "qux"}, result)
  end
  
  def test_decode_with_array
    result = HTTPTools::Encoding.www_form_decode("lang=en&lang=fr&q=foo&q=bar")
    
    assert_equal({"lang" => ["en", "fr"], "q" => ["foo", "bar"]}, result)
  end
  
  def test_encode_decode
    orginal = {"query" => "fish", "lang" => ["en", "fr"]}
    
    encoded = HTTPTools::Encoding.www_form_encode(orginal)
    decoded = HTTPTools::Encoding.www_form_decode(encoded)
    
    assert_equal(orginal, decoded)
  end
  
end