require 'coverage' # >= ruby 1.9 only

at_exit do
  testing = Dir[File.expand_path("../../lib/**/*.rb", __FILE__)]
  
  results = Coverage.result.select {|key, value| testing.include?(key)}
  
  puts
  total = results.map(&:last).flatten.compact
  puts "#{total.select {|i| i > 0}.length}/#{total.length} executable lines covered"
  puts
  
  results.each do |key, value|
    next unless value.include?(0)
    puts key
    puts " line calls code"
    puts
    File.readlines(key).zip(value).each_with_index do |(line, val), i|
      print val == 0 ? "> " : "  "
      print "%3i %5s %s" % [(i + 1), val, line]
    end
    puts
    puts
  end
end

Coverage.start
Dir[File.expand_path("../**/*_test.rb", __FILE__)].each {|test| require test}
