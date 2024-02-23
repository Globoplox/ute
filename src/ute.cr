require "string_scanner"

# The structure used internally for free forms parameters.
# It is built following the same logic as `JSON::Any` and `YAML::Any`.
struct Template::Parameters
  alias Type = String | Bool | Array(Parameters) | Hash(String, Parameters)
  getter raw : Type
  def initialize(@raw) end
  
  def to_s(io)
    io << @raw
  end
  
  def [](key : String) : Parameters
    raw.as(Hash(String, Parameters))[key]
  end
  
  def []?(key : String) : Parameters?
    raw.as(Hash(String, Parameters))[key]?
  end
    
  Empty = new Hash(String, Parameters).new
end

# A template manager. It serves as a repository of template to renders.
class Template::Manager

  record Raw, content : String
  record Symbol, name : Array(String)
  record Loop, source_name : Array(String), key_name : String?, value_name : String, body : Array(Component)
  record Conditional, source_name : Array(String), body : Array(Component)
  record Include, template_name : Array(String) | String, parameters : Array(String)?
  record Use, template_name : Array(String) | String, parameters : Array(String)?, anchors : Array(As) 
  record Anchor, name : String
  record As, anchor_name : String, body : Array(Component)
  
  alias Component = Raw | Symbol | Loop | Conditional | Include | Use | Anchor | As

  property cache

  # Create a manager. It will holds its own cache.
  # The *base* is used as a prefix for template when rendering them.
  # It is not omitted of the templates name in the cache. 
  def initialize(@base : String = nil)
    @cache = {} of Path => {timestamp: Time, components: Array(Component)}
  end

  # Macro used to produce a literal cache of all the templates
  # matched by the glob *patterns*.
  # If *base* is provided, the name of the templates in the produced 
  # cache will be relative to it.
  macro compile_time_cache(*patterns, base = nil)
    {% if base %}
      {{run "./dump", "-b", base, patterns.map(&.id).splat}}
    {% else %}
      {{run "./dump", patterns.map(&.id).splat}}
    {% end %}
  end

  # Macro to build a manager with a compile time built cache of all the
  # template found in the *base* directory relative to the compilation working dir. 
  # If omitted it default to the absolute compilation working dir.
  # It expect the templates files names to ends with the extension ".ut".
  macro build_with_cache(base = nil)
    begin
      {% pwd = "#{`pwd`.strip}" %}
      {% base ||= pwd %}
      {% initial_base = base %}
      {% sep = flag?(:win32) ? "\\" : "/" %}
      ::Template::Manager.new({{base}}).tap do |%manager|
      {%base = "#{pwd.id}#{sep.id}#{base.id}" unless base.starts_with? sep%}
        %manager.cache = ::Template::Manager.compile_time_cache "{{base.id}}{{sep.id}}**.ut", base: {{initial_base.starts_with?(sep) ? nil : pwd}}
      end
    end
  end

  # Extract an array of component of a string scanner
  # It expects to work recursively and so will stop at either end of string OR on '${end}' tags.
  def self.build(scanner, components = [] of Component, anchor_mode = false, expects_end = false)
    loop do
      offset = scanner.offset
      skip = scanner.skip_until /(\\*)(\${\s*([a-zA-Z0-9-_.\x22 \/\\+,]+)\s*})/
      if skip
        skip -= scanner[0].size
        escape = scanner[1]
        literal_component_text = scanner[2]
        before = scanner.string[offset, skip]

        # Handle escapement
        if escape.size > 0
          if escape.size.odd?
            # Escaped
            components << Raw.new before + ("\\" * (escape.size // 2)) + literal_component_text
            next
          else escape.size.even?
            # Not escaped
            before += "\\" * (escape.size // 2)
          end
        end
        
        component_text = scanner[3]
        trimmed_before = before

        # Check if line contains only whitespace before component
        to_trim = before.size
        has_text_before = before.reverse.each_char_with_index do |char, index|
          case char
          when '\n' then
            to_trim = index
            break false
          when .whitespace? then next
          else break true
          end
        end
        trimmed_before = before[start: 0, count: before.size - to_trim]
        
        # Check if line contains only whitespace after component.
        has_text_after = scanner.check_until('\n').try { |trailing| !trailing.blank? } || false

        result_component = case component_text

        when .match /^end$/
          raise "Unexpected end tag" unless expects_end
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          nil
        
        when .match /^if\s+([a-zA-Z-_.]+)$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          Conditional.new $1.split('.'), build scanner, expects_end: true

        when .match /^include\s+([a-zA-Z-_.]+)(\s+([a-zA-Z-_.]+))?$/
          Include.new $1.split('.'), $3?.try(&.split '.')

        when .match /^include\s+"([^"]+)"(\s+([a-zA-Z-_.]+))?$/
          Include.new $1, $3?.try(&.split '.')

        when .match /^anchor\s+([a-zA-Z-_]+)$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          Anchor.new $1

        when .match /^use\s+"([^"]+)"(\s+([a-zA-Z-_.]+))?$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          sub_components = build scanner, anchor_mode: true, expects_end: true
          Use.new $1, $3?.try(&.split '.'), sub_components.map { |component|
            component.as?(As) || raise "A 'Use' tag should only contain 'As' tags as direct children"
          }

        when .match /^use\s+([a-zA-Z-_.]+)(\s+([a-zA-Z-_.]+))?$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          sub_components = build scanner, anchor_mode: true, expects_end: true
          Use.new $1.split('.'), $3?.try(&.split '.'), sub_components.map { |component|
            component.as?(As) || raise "A 'Use' tag should only contain 'As' tags as direct children"
          }

        when .match /^as\s+([a-zA-Z-_]+)$/
          raise "Invalid 'as' tags outside of a 'use' tag" unless anchor_mode
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          As.new $1, build scanner,	expects_end: true

        when .match /^for\s+([a-zA-Z-_]+)\s+in\s+([a-zA-Z-_.]+)$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          Loop.new $2.split('.'), nil, $1, build scanner, expects_end: true

        when .match /^for\s+([a-zA-Z-_]+)\s*,\s*([a-zA-Z-_]+)\s+in\s+([a-zA-Z-_.]+)$/
          if !has_text_before && !has_text_after
            before = trimmed_before
            scanner.skip_until '\n'
          end
          Loop.new $3.split('.'), $1, $2, build scanner, expects_end: true

        when .match /^[a-zA-Z-_.]+$/
          Symbol.new $0.split '.'

        else raise "Invalid template syntax: '#{component_text}'"
        end

        components << Raw.new before if before.size > 0
        return components unless result_component
        components << result_component
        
      else
        scanner.terminate
        components << Raw.new scanner.string[offset..(scanner.offset)]
        break
      end
    end
    return components
  end

  # Render a template given its components, the parameters and a destination.
  # Parameter *anchors* is a stack of parameters for genereic templates (using anchor tags).
  #   The first is the most recent, the direct caller of the current template. If the caller itself is generic,
  #   then the stack will contains the parameters that have been given to it, ect.                                             
  def render(components : Array(Component), parameters, dest : IO, anchors : Array(Array(As))? = nil)
    components.each do |component|
      case component
      in As then raise "Unexpected usage of 'as' tags outside of a 'use' tag'"

      in Anchor
        # Allows usage of generic template as is without specialization ?
        # raise "Template is a generic template but is not used as is" unless anchors
        # Allows empty anchors ?
        anchors.try &.first.find(&.anchor_name.== component.name).try { |anchor|
          render anchor.body, parameters, dest, anchors.try &.[1..]
        }
        
      in Use
        sub_parameters = component.parameters.try { |name| name.reduce(parameters) { |a,b| a[b] }  } || parameters
        template_name = case name = component.template_name
        in Array(String) then name.reduce(parameters) { |a,b| a[b] }.raw.to_s
        in String then name
        end
        render template_name, sub_parameters, dest, anchors.try { |stack| [component.anchors] + stack }  || [component.anchors]
          
      in Include
        sub_parameters = component.parameters.try { |name| name.reduce(parameters) { |a,b| a[b] }  } || parameters
        template_name = case name = component.template_name
        in Array(String) then name.reduce(parameters) { |a,b| a[b] }.raw.to_s
        in String then name
        end
        render template_name, sub_parameters, dest
        
      in Conditional
        render component.body, parameters, dest if component.source_name.reduce(parameters) { |a, b| a.try &.[b]? }.try &.raw

      in Raw then dest << component.content 

      in Symbol
        dest << component.name.reduce(parameters) { |a, b| a[b] }

      in Loop
        loop_parameters = parameters.dup
        case container = component.source_name.reduce(parameters) { |a, b| a[b] }.raw
        when Array
          container.each_with_index do |value, index|
            component.key_name.try { |key_name| loop_parameters.raw.as(Hash)[key_name] = parameters.class.new (index + 1).to_s } 
            loop_parameters.raw.as(Hash)[component.value_name] = value
            render component.body, loop_parameters, dest
          end
        when Hash
          container.each_with_index do |(key, value)|
            component.key_name.try { |key_name| loop_parameters.raw.as(Hash)[key_name] = parameters.class.new key } 
            loop_parameters.raw.as(Hash)[component.value_name] = value
            render component.body, loop_parameters, dest
          end
        else raise "Bad type #{container.class}" unless container.is_a?(Array) || container.is_a?(Hash)
        end
      end
    end
  end

  # Convert free form parameters tree to a fixed known type.
  def self.normalize(parameters) : Parameters
    case parameters
    when String, Bool then Parameters.new parameters
    when Array then Parameters.new parameters.map { |sub| normalize sub }
    when Hash then Parameters.new parameters.transform_values { |sub| normalize sub }
    else raise "Unexpected parameters type: #{parameters.class}"
    end
  end

  # Render the given template by its *path* with the given *parameters*, into *dest*.
  # Parameters must be any ::Any like type such as Json::Any, Yaml::Any, or the provided Parameters type.
  # In case it is a raw hash, it will attempt to convert it to Parameters.
  def render(path : String | Path, parameters, dest : IO, anchors : Array(Array(As))? = nil)
    path = Path[path]
    @base.try { |base| path = Path[base, path] }
    cache = @cache[path]?

    mtime = File.info?(path).try &.modification_time

    if cache.nil? || (mtime && mtime > cache[:timestamp])
      scanner = StringScanner.new File.read path
      mtime || raise "Could not get info for file #{path} despite being able to read it"
      components = Manager.build scanner
      raise "Unexpected content at the end of the template at offset #{scanner.offset}" unless scanner.eos?
      @cache[path] = cache = {timestamp: mtime, components: components}
    end

    parameters = Manager.normalize parameters if parameters.is_a? Hash
    render cache[:components], parameters, dest, anchors
  end

  # Render the given template by its *path* with the given *parameters*, into *dest*.
  # If provided, *parameters* must be any ::Any like type such as Json::Any or the provided Parameters type,
  # or a combiantion of native Hash, Array, String and Bool.
  # Return the rendered template as a string.
  def render(path, parameters = Parameters::Empty) : String
    String::Builder.build do |io|
      render path, parameters, io
    end
  end
  
end
