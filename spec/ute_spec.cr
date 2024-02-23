require "./spec_helper"
require "json"
#require "yaml"

describe Template do

  it "Can render simple templates" do
    Template::Manager.new("spec")
      .render("greeting.ut", {"name" => "Bobby", "surname" => "Mc Test"})
      .should eq "Hey Bobby ! Still named Mc Test ?"
  end

  it "Handles escaping tags" do
    Template::Manager.new("spec")
      .render("escape.ut", {"test" => "true"})
      .should eq "Not escaped: true, Escaped: ${test}, Not escaped: \\true, Escaped: \\${test}, Not escaped: \\\\true"
  end

  it "Can render simple conditionals" do
    mgr = Template::Manager.new("spec")

    mgr.render("conditional.ut", {"user" => {"is_nice" => true, "name" => "Bob"}})
      .should eq "Hello magnificient Bob"

    mgr.render("conditional.ut", {"user" => {"is_nice" => false, "name" => "Bob"}})
      .should eq "Hello Bob"

    # Absence is allowed in conditionals parameter evaluation:
    mgr.render("conditional.ut", {"user" => {"name" => "Bob"}})
      .should eq "Hello Bob"
  end
  
  it "Can render loops with arrays" do
    Template::Manager.new("spec")
      .render("inline_list.ut", {"list" => ["lentils", "rice"]})
      .should eq "Grocery list: lentils rice. That's all."
  end

  it "Can render loops with arrays and index" do
    Template::Manager.new("spec")
      .render("index_list.ut", {"list" => ["lentils", "rice"]})
      .should eq "Grocery list: 1: lentils 2: rice. That's all."
  end

  it "Can render loops with hash" do
    Template::Manager.new("spec")
      .render("index_list.ut", {"list" => {"some" => "lentils", "much" => "rice"}})
      .should eq "Grocery list: some: lentils much: rice. That's all."
  end
  
  it "Nicely render loops with full-line tags" do
    Template::Manager.new("spec")
      .render("list.ut", {"list" => ["lentils", "rice"]})
      .should eq <<-TXT
        Grocery list
          - lentils
          - rice
        That's all
        TXT
  end

  it "Nicely render loops with nested elements" do
    Template::Manager.new("spec")
      .render("nested_list.ut", {"list" => [{"name" => "lentils", "value" => "some"}, {"name" => "rice", "value" => "much"}]})
      .should eq "List lentils: some rice: much."
  end

  it "Nicely render loops with JSON flavored parameters" do
    parameters = JSON.parse <<-JSON
    {"list": [{"name": "lentils", "value": "some"}, {"name": "rice", "value": "much"}]}
    JSON
    Template::Manager.new("spec")
      .render("nested_list.ut", parameters)
      .should eq "List lentils: some rice: much."
  end

  it "Can render generic templates" do
   Template::Manager.new("spec")
      .render("specialized.ut")
      .should eq "Hello Bob."
   end

  it "Can render generic templates with dynamic names" do
   Template::Manager.new("spec")
      .render("specialized_dynamic.ut", {"base_template_name" => "generic.ut"})
      .should eq "Hello Bob."
   end

  it "Can render generic templates with sub parameters for the base template" do
   Template::Manager.new("spec")
      .render("specialized_param.ut", {"base_sub_parameters" => {"greeter" => "wonderful "}})
      .should eq "Hello wonderful Bob."
   end
  
  it "Can render nested generics templates" do
    Template::Manager.new("spec")
      .render("daughter.ut")
      .should eq <<-TXT
      Grandmother start
      Mother start
      Hello from daughter !
      Mother end
      Grandmother end
      TXT
  end

  it "Can render template that includes other templates" do
    Template::Manager.new("spec")
      .render("includer.ut", {"name" => "Bob"})
      .should eq "Hello Bob"
  end

  it "Can includes with dynamic names" do
    Template::Manager.new("spec")
      .render("includer_dynamic.ut", {"template_to_include_name" => "included.ut", "name" => "Bob"})
      .should eq "Hello Bob"
  end

  it "Can includes with sub-parameters" do
    Template::Manager.new("spec")
      .render("includer_param.ut", {"param_to_use_within_included" => {"name" => "Bob"}})
      .should eq "Hello Bob"
  end

  it "Can build a compile time cache" do
    File.rename "spec/simplest.ut", "spec/moved_simplest.ut"
    Template::Manager.build_with_cache("spec")
      .render("simplest.ut")
      .should eq "hello"
  ensure
    File.rename "spec/moved_simplest.ut", "spec/simplest.ut"
  end
  
  # it "Nicely render loops with YAML flavored parameters" do
  #   parameters = YAML.parse <<-YAML
  #   list:
  #     - name: lentils
  #       value: some
  #     - name: rice
  #       value: some  
  #   YAML
  #   Template::Manager.new("spec")
  #     .render("nested_list.ut", parameters)
  #     .should eq "List lentils: some rice: much."
  # end

  
end
