#!/usr/bin/env ruby
# frozen_string_literal: true

def trim(str)
  str.gsub!(/ *__attribute__\(\(.+\)\)/, '')
  str.gsub!(/ *__deprecated_msg\(.+\)/, '')
  str.gsub!(/ *FAB_UNAVAILABLE\(.+\)/, '')
  str.gsub!(/ *GAD_DEPRECATED_MSG_ATTRIBUTE\(.+\)/, '')
  str.gsub!(/(__)?(al)?nullable */, '')
  str.gsub!(/(__)?(al)?nonnull */, '')
  str.gsub!(/ *__AL_TVOS_PROHIBITED/, '')
  str.gsub!(/ *NS_DESIGNATED_INITIALIZER/, '')
end

def default_value(type)
  case type
  when 'float'
    '0.0'
  when 'BOOL'
    'NO'
  when /^id(<.+>)?/, /\w+\s*\*/, 'instancetype'
    'nil'
  when 'void'
    nil
  when 'ImobileSdkAdsStatus'
    'IMOBILESDKADS_STATUS_RETRY_WAIT'
  when 'NetworkStatus'
    'ReachableViaWWAN'
  when 'CGPoint'
    'CGPointZero'
  when 'CGSize'
    'CGSizeZero'
  when 'CGRect'
    'CGRectZero'
  else
    throw "unknown type: #{type}"
  end
end

def print_stub(return_type)
  return_value = default_value(return_type)
  puts '{'
  puts '    NSLog(@"*** %s is not implemented", __FUNCTION__);'
  puts "    return #{return_value};" if return_value
  puts '}'
  puts ''
end

in_protocol = false
in_method_decl = false
return_type = nil

ARGF.each do |line|
  line.strip!

  case line
  when /@interface +(\w+) *:/
    interface_name = Regexp.last_match(1)
    puts ''
    puts "@implementation #{interface_name}"
  when /@protocol/
    in_protocol = true unless line.match?(/;/)
  when /(\+|-) *\(.+/
    next if in_protocol
    trim(line)
    return_type = line.match(/\(([^)]+)\)/)[1].strip
    if line.match?(/;/)
      puts line.delete(';')
      print_stub(return_type)
    else
      print line + ' '
      in_method_decl = true
    end
  when /;/
    next if in_protocol
    if in_method_decl
      trim(line)
      puts line.delete(';')
      print_stub(return_type)
      in_method_decl = false
    end
  when /@end/
    if in_protocol
      in_protocol = false
    else
      puts '@end'
    end
  else
    if in_method_decl
      trim(line)
      print line + ' '
    end
  end
end
