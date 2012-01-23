# encoding: ASCII-8BIT
base = File.expand_path(File.dirname(__FILE__) + '/../../lib')
require base + '/http_tools'
require 'test/unit'

class WWWFormTest < Test::Unit::TestCase
  
  def ruby_one_nine_or_greater?
    ruby_version = RUBY_VERSION.split(".").map {|d| d.to_i}
    ruby_version[0] > 1 || (ruby_version[0] == 1 && ruby_version[1] >= 9)
  end
  
  def test_encode
    result = HTTPTools::Encoding.www_form_encode("foo" => "bar", "baz" => "qux")
    
    if ruby_one_nine_or_greater?
      assert_equal("foo=bar&baz=qux", result)
    else
      assert_equal(["baz=qux", "foo=bar"], result.split("&").sort)
    end
  end
  
  def test_encode_with_array
    result = HTTPTools::Encoding.www_form_encode("lang" => ["en", "fr"], "q" => ["foo", "bar"])
    
    if ruby_one_nine_or_greater?
      assert_equal("lang=en&lang=fr&q=foo&q=bar", result)
    else
      assert_equal(["lang=en", "lang=fr", "q=bar", "q=foo"], result.split("&").sort)
    end
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
