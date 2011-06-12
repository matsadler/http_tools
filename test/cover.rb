#!/opt/local/bin/ruby1.9 -w

require 'coverage' # >= ruby 1.9 only

at_exit do
  testing = Dir["../lib/**/*.rb"].map(&File.method(:expand_path))
  
  results = Coverage.result.select {|key, value| testing.include?(key)}
  
  puts
  total = results.map(&:last).flatten.compact
  puts "#{total.select {|i| i > 0}.length}/#{total.length} executable lines covered"
  puts
  
  results.each do |key, value|
    next unless value.include?(0)
    puts key
    puts
    File.readlines(key).zip(value).each_with_index do |(line, val), i|
      print "%3i %3s  %s" % [(i + 1), val, line]
    end
    puts
    puts
  end
end

Coverage.start
Dir["**/*_test.rb"].each {|test| require test}