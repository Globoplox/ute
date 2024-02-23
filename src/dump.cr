require "./ute"
require "option_parser"

# This is a CLI tool that output the crystal code for 
# creating a literal cache of templates.

rt_base_path = nil
patterns = [] of String

OptionParser.parse do |parser|
  parser.on("-b BASE", "--base=BASE", "Make the template names relative to given path") { |name| rt_base_path = name }
  parser.unknown_args do |args, dash_args|
    patterns += args + dash_args
  end
end

cache = {} of Path => {timestamp: Time, components: Array(Template::Manager::Component)}

patterns.each do |pattern|
  Dir[pattern].each do |path|
    name = path = Path[path]
    name = name.relative_to rt_base_path.not_nil! if rt_base_path
    cache[name] = {timestamp: File.info(path).modification_time, components: Template::Manager.build(StringScanner.new(File.read(path)))}
  end
end

dump cache, STDOUT

def dump(any, io)
  case any

  when Hash(Path, {timestamp: Time, components: Array(Template::Manager::Component)})
    if any.empty?
      io << "{} of Path => {timestamp: ::Time, components: ::Array(::Template::Manager::Component)}"
    else
      io << '{'
      any.each do |k,v|
        dump k, io
        io << "=>"
        dump v, io
        io << ','
      end
      io << '}'
    end

  when Path
    io << "Path["
    dump any.to_s, io
    io << ']'

  when NamedTuple(timestamp: Time, components: Array(Template::Manager::Component))
    io << "{timestamp: "
    dump any[:timestamp], io
    io << ", components: "
    dump any[:components], io    
    io << '}'
    
  when Time
    io << "::Time.parse_iso8601("
    dump any.to_rfc3339, io
    io << ')'

  when String
    io << any.dump

  when Array(String)
    io << '['
    any.each do |e|
      dump e, io
      io << ','
    end
    io << "] of String"
    
  when Array(Template::Manager::Component)
    io << '['
    any.each do |e|
      io << '\n'
      dump e, io
      io << ','
    end
    io << "] of ::Template::Manager::Component"
    

  when Array(Template::Manager::As)
    io << '['
    any.each do |e|
      dump e, io
      io << ','
    end
    io <<  "] of ::Template::Manager::As"
    
  # record Raw, content : String
  when Template::Manager::Raw
    io << "::Template::Manager::Raw.new("
    dump any.content, io
    io << ')'

  when Template::Manager::Symbol
   io << "::Template::Manager::Symbol.new("
   dump any.name, io
   io << ')'

  when Template::Manager::Loop
    io << "::Template::Manager::Loop.new("
    dump any.source_name, io
    io << ','
    dump any.key_name, io
    io << ','
    dump any.value_name, io
    io << ','
    dump any.body, io
    io << ')'

  when Template::Manager::Conditional
    io << "::Template::Manager::Conditional.new("
    dump any.source_name, io
    io << ','
    dump any.body, io
    io << ')'

  when Template::Manager::Include
    io << "::Template::Manager::Include.new("
    dump any.template_name, io
    io << ','
    dump any.parameters, io
    io << ')'

  when Template::Manager::Use
    io << "::Template::Manager::Use.new("
    dump any.template_name, io
    io << ','
    dump any.parameters, io
    io << ','
    dump any.anchors, io
    io << ')'

  when Template::Manager::Anchor
    io << "::Template::Manager::Anchor.new("
    dump any.name, io
    io << ')'

  when Template::Manager::As
    io << "::Template::Manager::As.new("
    dump any.anchor_name, io
    io << ','
    dump any.body, io
    io << ')'

  when nil
    io << "nil"
    
  else raise "Failed to dump representation of type #{any.class}"
  end
end  
