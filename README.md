# Ute

A lightweight template engine in pure crystal. Built for my own entertainment.  
Probably somewhat unfinished as when I write these lines I have done what I wanted to with this pet project.

It handles:
- Nested parameters
- Simple conditionals
- Loops
- Inclusion of other templates (composition)
- Usage of base templates (kind of inhertiance)
- Escapement
- Whitespace handling (WIP)
- Caching
- Low hassle parameters
- Compile time caching

It would like to handle but is unlikely because im growing bored of this project:
- More complex conditonals
- Default values
- Better whitespace handling
- Disablable whitespace handling
- Default body for anchor tags
- Loose and strict modes
- Compatibility with `YAML::Any` as parameters

## Syntax and features

### Basic

Tags are denoted by `${...}`.  
Simple tags with an identifier will output the value of the parameters
named this way:

```txt
Hello ${name}
```

Will render as:
```txt
Hello Bob
```

### Nested

Parameters can be nested and accessed through a chain:

The template:
```txt
Hello ${user.name}.
```

Will render as:
```txt
Hello Bob.
```

### Escapement

In case you need to output tags literaly, they can be escaped:

```txt
Hello ${name}
Hello \${name}
Hello \\${name}
Hello \\\${name}
Escapement is not needed in raw text: \\\
```

Will render as:
```txt
Hello Bob
Hello ${name}
Hello \Bob
Hello \${name}
Escapement is not needed in raw text: \\\
```

### Conditonals

Simpel conditions are supported:
```txt
Hello ${if user.is_nice}magnificient ${end}${user.name}
```

Might render as:
```txt
Hello Bob
```
or 
```txt
Hello magnificient Bob
```
depending on the truthyness of the `user.is_nice` parameter.

If the parameter is missing entierly, it will be considered falsey.

### Loops

```txt
List:${for item of items} ${item}${end}.
```

Will render as:
```txt
List: lentils rice.
```

Loops supports keys and indexes too:

```txt
${for key, value of items} 
${key}: ${item}
${end}
```

With array parameters:   
`{"items" => ["lentils", "rice"]}`:
```txt
1: lentils
2: rice
```

With hash parameters:  
`{"items" => {"some" => "lentils", "much" => "rice"}}`:
```txt
some: lentils
much: rice
```

### Inclusion

A template can include another template:  
*web.ut*:
```txt
...
<body>
${include "content.ut"}
</body>
```

*content.ut*:
```txt
Some cool informations
```

The *web.ut* template will render as:
```txt
...
<body>
Some cool informations
</body>
```

#### Parameters

Included templates receive the same parameters as the including template by default. This can be changed with an optionnal parameter name after the template name:
```txt
${include "some_template.ut" the_parameter.it_will_receive}
```

#### Dynamic template names

The included template name can be dynamic and stored in a parameter. In this case the template name must be replaced buy the parameter holding it and quotes must be ommitted:
```txt
${include some.template.name}
```

### Generic templating

It is possible to defines a base template with reserved spaces to be filled by another template later.  The inheriting template will specify which mother template to use, and the content to put in each empty space.  

A base template:
```txt
Some header
${anchor body_content}
Some footer
```

An inheriting template:
```txt
${use "mother_template_path"}
${as body_content}
This is the content that  will appear instead of the \${anchor body_content}, 
while the content of the mother will appear instead of \${use "mother_template_path"}
${end}
${end}
```

The inheriting template will render as:
```txt
Some header
This is the content that will appear instaed of the \${anchor_body_content},
while the content of the mother will appear instead of \${use "mother_template_path"}
Some footer
```

Similarly to [inclusion](#inclusion), inherited template names
can be dynamic and provided as a parameter.
A second parameters can be added to specify the root of the parameters used by the rendering templats.


> [!NOTE]
> There might be several 'anchor' in a template, and so several 'as' tags in a 'use' tag body.
>
> There might be several 'use' tag within the same template.
>
> Templates can be nested both ways: a template can use both 'use' tags and 'anchor' tags.

> [!WARNING]
> When changing the parameters given to the base template, those new parameters will be applied within the body of the `${as ...}` tags of the inheriting template.
>
> This is subject to future changes.

### Whitespace handling

In order to make template easier to write and read, when a control (that does not output anything by itself) template tag is the only none whitespace text in the line, the line is not outputed. It allows for a nicer structuring of the templates:  

The template
```txt
List:
${for item in items}
- ${item}
${end}
End of the list.
```

Will render:   
```txt
List:
- a
- b
End of the list.
```

and not:
```txt
List:
- a

- b 

End of the list
```

> [!CAUTION]
> This may not work perfectly well, it might consider the tag alone in the line even if there are another tag, or content 'hidden' by another tag, previously in the line. This is due to the method of scanning the whole file for tags, instead of working line per line.
>
> This is subject to future changes.  


## Parameters

Parameters can be provided in several ways:

### Provided format

There is a `Template::Parameters` type that can be used to holds parameters:
```crystal
parameters = Template::Parameters.new({
  "name" => Template::Parameters.new("Bob"),
  "friends" => Template::Parameters.new([
	  Template::Parameters.new("John")
  ])
})
```

However native crystal types can be used as is, they will be converted internally:
```crystal
parameters = {
  "name" => "Bob",
  "friends" => [
    "John"
  ]
}
``` 

> [!NOTE]
> When using native types, the following are alloweds:
> - String
> - Bool
> - Array()
> - Hash(String, )

### JSON::Any

The parameters can also be provided as a [`JSON::Any`](https://crystal-lang.org/api/1.11.2/JSON/Any.html):
```crystal
require "json"
require "ute"

manager = Template::Manager.new
manager.render "template", JSON.parse <<-JSON
{
  "name": "Bob",
  "friends": [
    "John"
  ]
}
JSON  
```

### YAML::Any

While it is desired, using [`YAML::Any`](https://crystal-lang.org/api/1.11.2/YAML/Any.html) as parameters is not yet supported. 

The reasons is that `YAML::Any` hashes use `YAML::Any` as keys and not `String`, which require some adaptation to handle.

### Anything else you want

Any custom type can be given as parameters, as long as it implements the following constructor and methods:
```crystal
abstract class YourCustomType
  abstract def initialize(raw : Whatever)
  abstract def [](key : String) : self
  abstract def []?(key : String) : self?
  abstract def raw : Whatever
end
```

Loops tags expect the given parameter `raw` value to be one of `Array(self)` or `Hash(String, self)`.

The method `to_s` will be called when inserting a parameter into the result.

As for conditonal, the `raw` method will be used as is, so crystal truthy/falsey rules applies.

## Caching

A `Template::Manager` will cache an intermediary representation of each template it renders. The cache will be invalidated if the orignal template file exists and has a modification time later than the one of the version cached.

The cache is easily accessible as `Template::Manager#cache`.

The entries in the cache are indexed through the name of the template, with the base path of the template manager if it has one. You can consider the bath path to only be a quality of life when all the templates are in a single directory.

### At compile time

It is possible to create a cache of the intermediary representation of templates at compile time (thus embedding the "templates" into the compiled binary).

This cache wil behave exactly as usual, which mean it is possible to compile a program with his template and run it elswhere without them, then later add one of the template back to update it if needed.

Note that using the compile time cache will increase compilation times (especially when compiling with it for the first time).

```
require "ute"

# Important note: `#build_with_cache` is a macro
#  which mean the parameter MUST be a literal string
# It also means that you should avoid using it for the same dir in several codebase locations.

mgr = Template::Manager.build_with_cache "spec"

# mgr will have all the templates within ./spec in its cache immediately at runtime, even  if the template on the filesystem are gone.
```

For a finer control, you can use 

`Template::Manager#compile_time_cache(*patterns, base = nil)`

Which will generate the cache literal for all the templates matched by the patterns. The template names will be made relative to `base` if given.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     ute:
       github: globoplox/ute
   ```

2. Run `shards install`

## Usage

```crystal
require "ute"

template_dir = ENV["TEMPLATE_DIR"]?

# The directory parameter is optional. It defaults to the current parameter.
mgr = Template::Manager.new template_dir

# Render a template:
rendered = mgr.render "example.ut"

# With parameters:
parameters = {"some" => "parameters"}
rendered = mgr.render "exemple.ut", parameters

# Render into an IO:
dest = IO::Memory.new
mgr.render "example.ut", parameters, dest
rendered = dest.tap(&.rewind).gets_to_end
```

You can find more examples in the `spec` folder.
