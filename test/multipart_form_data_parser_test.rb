# encoding: ASCII-8BIT
base = File.expand_path(File.dirname(__FILE__) + '/../lib')
require base + '/http_tools'
require 'test/unit'

class MultipartFormDataParserTest < Test::Unit::TestCase
  
  DATA = <<-DATA.chomp.freeze
--AaB03x\r
Content-Disposition: form-data; name="submit-name"\r
\r
Larry\r
--AaB03x\r
Content-Disposition: form-data; name="files"; filename="file1.txt"\r
Content-Type: text/plain\r
\r
... contents of file1.txt ...\r
--AaB03x--
  DATA
  BOUNDRY = "AaB03x".freeze
  EXPECTED = [
    {:header => {"Content-Disposition" => "form-data; name=\"submit-name\""}.freeze,
    :data => "Larry"}.freeze,
    {:header => {"Content-Disposition" => "form-data; name=\"files\"; filename=\"file1.txt\"",
      "Content-Type" => "text/plain"}.freeze,
    :data => "... contents of file1.txt ..."}.freeze,
  ].freeze
  
  def setup
    @parser = HTTPTools::MultipartFormDataParser.new(BOUNDRY)
    @parts = []
    @parser.on(:header) do |header|
      part = {:header => header, :data => ""}
      @parts << part
      @parser.on(:stream) {|chunk| part[:data] << chunk}
    end
  end
  
  def teardown
    @parser = nil
    @parts = nil
    @parser = nil
  end
  
  def assert_correctly_parsed
    assert_equal(EXPECTED, @parts)
    assert_equal(:end_of_message, @parser.state)
  end
  
  def test_all_in_one_go
    @parser.call(DATA)
    
    assert_correctly_parsed
  end
  
  def test_char_by_char
    DATA.scan(/./m).each {|c| @parser.call(c)}
    
    assert_correctly_parsed
  end
  
  def test_variable_chunk_size
    (1..10).each do |i|
      DATA.scan(/.{1,#{i}}/m).each {|c| @parser.call(c)}
      
      assert_correctly_parsed
      
      @parser.reset(BOUNDRY)
      @parts.clear
    end
  end
  
  def test_random_chunk_size
    100.times do
      index = 0
      while index < DATA.length
        n = rand(14)
        @parser.call(DATA[index, n])
        index += n
      end
      
      assert_correctly_parsed
      
      @parser.reset(BOUNDRY)
      @parts.clear
    end
  end
  
  def test_without_carriage_return
    @parser.call(DATA.delete("\r"))
    
    assert_correctly_parsed
  end
  
end
