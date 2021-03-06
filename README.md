# CsvRowModel [![Build Status](https://travis-ci.org/FinalCAD/csv_row_model.svg?branch=master)](https://travis-ci.org/FinalCAD/csv_row_model) [![Code Climate](https://codeclimate.com/github/FinalCAD/csv_row_model/badges/gpa.svg)](https://codeclimate.com/github/FinalCAD/csv_row_model) [![Test Coverage](https://codeclimate.com/github/FinalCAD/csv_row_model/badges/coverage.svg)](https://codeclimate.com/github/FinalCAD/csv_row_model/coverage)

Import and export your custom CSVs with a intuitive shared Ruby interface.

First define your schema:

```ruby
class ProjectRowModel
  include CsvRowModel::Model

  column :id, options
  column :name
  
  merge_options :id, more_options # optional
end
```

To export, define your export model like [`ActiveModel::Serializer`](https://github.com/rails-api/active_model_serializers)
and generate the file:

```ruby
class ProjectExportRowModel < ProjectRowModel
  include CsvRowModel::Export

  # this is an override with the default implementation
  def id
    source_model.id
  end
end

export_file = CsvRowModel::Export::File.new(ProjectExportRowModel)
export_file.generate { |csv| csv << project } # `project` is the `source_model` in `ProjectExportRowModel`
export_file.file # => <Tempfile>
export_file.to_s # => export_file.file.read
```

To import, define your import model, which works like [`ActiveRecord`](http://guides.rubyonrails.org/active_record_querying.html),
and iterate through a file:

```ruby
class ProjectImportRowModel < ProjectRowModel
  include CsvRowModel::Import

  # this is an override with the default implementation
  def id
    original_attribute(:id)
  end
end

import_file = CsvRowModel::Import::File.new(file_path, ProjectImportRowModel)
row_model = import_file.next

row_model.headers # => ["id", "name"]

row_model.source_row # => ["1", "Some Project Name"]
row_model.source_attributes # => { id: "1", name: "Some Project Name" }, this is `source_row` mapped to `column_names`
row_model.attributes # => { id: "1", name: "Some Project Name" }, this is final attribute values mapped to `column_names`

row_model.id # => 1
row_model.name # => "Some Project Name"

row_model.previous # => <ProjectImportRowModel instance>
row_model.previous.previous # => nil, save memory by avoiding a linked list
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'csv_row_model'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install csv_row_model

## Export

### Header Value
To generate a header value, the following pseudocode is executed:
```ruby
def header(column_name)
  # 1. Header Option
  header = options_for(column_name)[:header]

  # 2. format_header
  header || format_header(column_name, context)
end
```

#### Header Option
Specify the header manually:
```ruby
class ProjectRowModel
  include CsvRowModel::Model
  column :name, header: "NAME"
end
```

#### Format Header
Override the `format_header` method to format column header names:
```ruby
class ProjectExportRowModel < ProjectRowModel
  include CsvRowModel::Export
  class << self
    def format_header(column_name, context)
      column_name.to_s.titleize
    end
  end
end
```

## Import

### Attribute Values
To generate a attribute value, the following pseudocode is executed:

```ruby
def original_attribute(column_name)
  # 1. Get the raw CSV string value for the column
  value = source_attributes[column_name]

  # 2. Clean or format each cell
  value = self.class.format_cell(cell, column_name, context)

  if value.present?
    # 3a. Parse the cell value (which does nothing if no parsing is specified)
    parse(value)
  elsif default_exists?
    # 3b. Set the default
    default_for_column(column_name)
  end
end

def original_attributes; { id: original_attribute(:id) } end
def id; original_attribute(:id) end
```

#### Format Cell
Override the `format_cell` method to clean/format every cell:
```ruby
class ProjectImportRowModel < ProjectRowModel
  include CsvRowModel::Import
  class << self
    def format_cell(cell, column_name, context)
      cell = cell.strip
      cell.blank? ? nil : cell
    end
  end
end
```

#### Type
Automatic type parsing.

```ruby
class ProjectImportRowModel
  include CsvRowModel::Import

  column :id, type: Integer
  column :name, parse: ->(original_string) { parse(original_string) }

  def parse(original_string)
    "#{id} - #{original_string}"
  end
end
```

There are validators for available types: `Boolean`, `Date`, `DateTime`, `Float`, `Integer`. See [Type Format](#type-format) for more. You can also customize and create new types via a override:

```ruby
class ProjectImportRowModel
  # GOTCHA: this should be defined before `::column` is called,
  # as `::column` uses this to check passed `:type` option (and return ArgumentError)
  def self.class_to_parse_lambda
    super.merge(
      Hash => ->(s) { JSON.parse(s) },
      'CommaList' => ->(s) { s.split(",").map(&:strip) }
    )
  end
end
```

#### Default
Sets the default value of the cell:
```ruby
class ProjectImportRowModel
  include CsvRowModel::Import

  column :id, default: 1
  column :name, default: -> { get_name }

  def get_name; "John Doe" end
end
row_model = ProjectImportRowModel.new(["", ""])
row_model.id # => 1
row_model.name # => "John Doe"
row_model.default_changes # => { id: ["", 1], name: ["", "John Doe"] }
```

`DefaultChangeValidator` is provided to allows to add warnings when defaults are set. See [Default Changes](#default-changes) for more.

### Validations

[`ActiveModel::Validations`](http://api.rubyonrails.org/classes/ActiveModel/Validations.html) and [`ActiveWarnings`](https://github.com/s12chung/active_warnings)
are included for errors and warnings.

There are layers to validations.

```ruby
class ProjectImportRowModel
  include CsvRowModel::Import
  
  # Errors - by default, an Error will make the row skip
  validates :id, numericality: { greater_than: 0 } # ActiveModel::Validations
  
  # Warnings - a message you want the user to see, but will not make the row skip
  warnings do # ActiveWarnings, see: https://github.com/s12chung/active_warnings
    validates :some_custom_string, presence: true
  end
  
  # This is for validation of the strings before parsing. See: https://github.com/FinalCAD/csv_row_model#parsedmodel
  parsed_model do
    validates :id, presence: true
    # can do warnings too
  end
end
```

#### Type Format
Notice that there are validators given for different types: `Boolean`, `Date`, `DateTime`, `Float`, `Integer`:

```ruby
class ProjectImportRowModel
  include CsvRowModel::Import

  column :id, type: Integer, validate_type: true

  # the :validate_type option is the same as:
  # parsed_model do
  #   validates :id, integer_format: true, allow_blank: true
  # end
end

ProjectRowModel.new(["not_a_number"])
row_model.valid? # => false
row_model.errors.full_messages # => ["Id is not a Integer format"]
```

The above uses `IntegerFormatValidator` internally, you may customize this class or create new validators for custom types.

#### Default Changes
A custom validator for [Default Changes](#default).

```ruby
class ProjectImportRowModel
  include CsvRowModel::Input

  column :id, default: 1
  validates :id, default_change: true
end

row_model = ProjectImportRowModel.new([""])

row_model.valid? # => false
row_model.errors.full_messages # => ["Id changed by default"]
row_model.default_changes # => { id: ["", 1] }
```

### Skip and Abort
You can iterate through a file with the `#each` method, which calls `#next` internally.
`#next` will always return the next `RowModel` in the file. However, you can implement skips and
abort logic:

```ruby
class ProjectImportRowModel
  # always skip
  def skip?
    true # original implementation: !valid?
  end
end

import_file = CsvRowModel::Import::File.new(file_path, ProjectImportRowModel)
import_file.each { |project_import_model| puts "does not yield here" }
import_file.next # does not skip or abort
```

### File Validations
You can also have file validations, while will make the entire import process abort. Currently, there is one provided validation.

```ruby
class ImportFile < CsvRowModel::Import::File
  validate :headers_invalid_row # checks if header is valid CSV syntax
  validate :headers_count # calls #headers_invalid_row, then check the count. will ignore tailing empty headers
end
```

Can't be used for [File Model](#file-model) schemas.

### Import Callbacks
`CsvRowModel::Import::File` can be subclassed to access
[`ActiveModel::Callbacks`](http://api.rubyonrails.org/classes/ActiveModel/Callbacks.html).

* each_iteration - `before`, `around`, or `after` the an iteration on `#each`.
Use this to handle exceptions. `return` and `break` may be called within the callback for
skips and aborts.
* next - `before`, `around`, or `after` each change in `current_row_model`
* skip - `before`
* abort - `before`

and implement the callbacks:
```ruby
class ImportFile < CsvRowModel::Import::File
  around_each_iteration :logger_track
  before_skip :track_skip

  def logger_track(&block)
    ...
  end

  def track_skip
    ...
  end
end
```

## Advanced Import

### ParsedModel
The `ParsedModel` represents a row BEFORE parsing to add validations.

```ruby
class ProjectImportRowModel
  include CsvRowModel::Import

  # Note the type definition here for parsing
  column :id, type: Integer

  # this is applied to the parsed CSV on the model
  validates :id, numericality: { greater_than: 0 }

  parsed_model do
    # define your parsed_model here

    # this is applied BEFORE the parsed CSV on parsed_model
    validates :id, presence: true

    def random_method; "Hihi" end
  end
end

# Applied to the String
ProjectImportRowModel.new([""])
parsed_model = row_model.parsed_model
parsed_model.random_method => "Hihi"
parsed_model.valid? => false
parsed_model.errors.full_messages # => ["Id can't be blank'"]

# Errors are propagated for simplicity
row_model.valid? # => false
row_model.errors.full_messages # => ["Id can't be blank'"]

# Applied to the parsed Integer
row_model = ProjectRowModel.new(["-1"])
row_model.valid? # => false
row_model.errors.full_messages # => ["Id must be greater than 0"]
```

Note that `ParsedModel` validations are calculated after [Format Attribute](#format-cell) and custom validators can't be autoloaded---[non-reloadable classes can't access reloadable ones](http://stackoverflow.com/questions/29636334/a-copy-of-xxx-has-been-removed-from-the-module-tree-but-is-still-active).

### Represents
A CSV is often a representation of database model(s), much like how JSON parameters represents models in requests.
However, CSVs schemas are **flat** and **static** and JSON parameters are **tree structured** and **dynamic** (but often static).
Because CSVs are flat, `RowModel`s are also flat, but they can represent various models. The `represents` interface attempts to simplify this for importing.

```ruby
class ProjectImportRowModel < ProjectRowModel
  include CsvRowModel::Import

  # this is shorthand for the psuedo_code:
  # def project
  #  return if id.blank? || name.blank?
  #
  #  # turn off memoziation with `memoize: false` option
  #  @project ||= __the_code_inside_the_block__
  # end
  #
  # and the psuedo_code:
  # def valid?
  #   super # calls ActiveModel::Errors code
  #   errors.delete(:project) if id.invalid? || name.invalid?
  #   errors.empty?
  # end
  represents_one :project, dependencies: [:id, :name] do
     project = Project.where(id: id).first
                           
     # project not found, invalid.
     return unless project

     project.name = name
     project
   end
   
   # same as above, but: returns [] if name.blank?
   represents_many :projects, dependencies: [:name] do
     Project.where(name: name)
   end
end

# Importing is the same
import_file = CsvRowModel::Import::File.new(file_path, ProjectImportRowModel)
row_model = import_file.next
row_model.project.name # => "Some Project Name"
```

The `represents_one` method defines a dynamic `#project` method that:

1. Memoizes by default, turn off with `memoize: false` option
2. Handles dependencies:
  - When any of the dependencies are `blank?`, the attribute block is not called and the representation returns `nil`.
  - When any of the dependencies are `invalid?`, `row_model.errors` for dependencies are cleaned. For the example above, if `id/name` are `invalid?`, then
the `:project` key is removed from the errors, so: `row_model.errors.keys # => [:id, :name]` (applies to warnings as well)

`represents_many` is also available, except it returns `[]` when any of the dependencies are `blank?`.

### Children

Child `RowModel` relationships can also be defined:

```ruby
class UserImportRowModel
  include CsvRowModel::Import

  column :id, type: Integer
  column :name
  column :email

  # uses ProjectImportRowModel#valid? to detect the child row
  has_many :projects, ProjectImportRowModel
end

import_file = CsvRowModel::Import::File.new(file_path, UserImportRowModel)
row_model = import_file.next
row_model.projects # => [<ProjectImportRowModel>, ...]
```

## Dynamic Columns
Dynamic columns are columns that can expand to many columns. Currently, we can only one dynamic column after all other standard columns.
The following:

```ruby
class DynamicColumnModel
  include CsvRowModel::Model

  column :first_name
  column :last_name
  # header is optional, below is the default_implementation
  dynamic_column :skills, header: ->(skill_name) { skill_name }, header_models_context_key: :skills
end
```

represents this table:

| first_name | last_name  | skill1 | skill2 |
| ---------- |----------- | ------ | ------ |
| John       | Doe        |   No   |   Yes  |
| Mario      | Super      |   Yes  |   No   |
| Mike       | Jackson    |   Yes  |   Yes  |


The `format_dynamic_column_header(header_model, column_name, context)` can
be used to defined like `format_header`. Defined in both import and export due to headers being used for both.

### Export
Dynamic column attributes are arrays, but each item in the array is defined via singular attribute method like
normal columns:

```ruby
class DynamicColumnExportModel < DynamicColumnModel
  include CsvRowModel::Export

  def skill(skill_name)
    # below is an override, this is the default implementation: skill_name # => "skill1", then "skill2"
    source_model.skills.include?(skill_name) ? "Yes" : "No"
  end
end

# `skills` in the context is used as the header, which is used in `def skill(skill_name)` above
# to change this context key, use the :header_models_context_key option
export_file = CsvRowModel::Export::File.new(DynamicColumnExportModel, { skills: Skill.all  })
export_file.generate do |csv|
  User.all.each { |user| csv << user }
end
```

### Import
Like Export above, each item of the array is defined via singular attribute method like
normal columns:

```ruby
class DynamicColumnImportModel < DynamicColumnModel
  include CsvRowModel::Import

  # this is an override with the default implementation (override highly recommended)
  def skill(value, skill_name)
    value
  end

  class << self
    # Clean/format every dynamic_column attribute array
    #
    # this is an override with the default implementation
    def format_dynamic_column_cells(cells, column_name, context)
      cells
    end
  end
end
row_model = CsvRowModel::Import::File.new(file_path, DynamicColumnImportModel).next
row_model.attributes # => { first_name: "John", last_name: "Doe", skills: ['No', 'Yes'] }
row_model.skills # => ['No', 'Yes']
```

## File Model

A File Model is a RowModel where the row represents the entire file. It looks like this:

| id   |  1   |
|------|------|
| name | abc  |

```ruby
class FileRowModel
  include CsvRowModel::Model
  include CsvRowModel::Model::FileModel

  row :id
  row :name
end
```

The `:header` option is not available. It is a unfinished/unpolished API, so things may change.

### Import

For File Model Import, the headers are matched via regex and the value is the cell to right of the header.
When defining the schema, the order of the `row` calls do not matter.

```ruby
class FileImportModel < FileRowModel
  include CsvRowModel::Import
  include CsvRowModel::Import::FileModel
end
```

### Export

For File Model Export, you have to define a template, where you fill in the values of each cell. Symbol values will match the row's header.

```ruby
class FileExportModel < FileRowModel
  include CsvRowModel::Export
  include CsvRowModel::Export::FileModel

  def rows_template
    @rows_template ||= begin
      [
        [:id, id],
        ['', :name, name]
      ]
    end
  end
  
  def name
    source_model.name.upcase
  end
end
```
