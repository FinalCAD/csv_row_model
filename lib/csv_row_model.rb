autoload = false
# autoload = true #uncomment for testing purposes only, not covered by rspec

class Boolean; end unless defined? Boolean

require 'active_model'
require 'active_support/all'
require 'active_warnings'
require 'csv'

require 'csv_row_model/validators/default_change'

if autoload && defined?(Rails)
  require 'csv_row_model/engine'
else
  require 'csv_row_model/version'

  require 'csv_row_model/concerns/inspect'
  require 'csv_row_model/concerns/deep_class_var'

  require 'csv_row_model/validators/validate_attributes'

  require 'csv_row_model/model'

  require 'csv_row_model/coercer'
  require 'csv_row_model/import'
  require 'csv_row_model/import/csv'
  require 'csv_row_model/import/file'
  require 'csv_row_model/import/mapper'


  require 'csv_row_model/export'
  require 'csv_row_model/export_collection/csv'
end

module CsvRowModel
  class RowModelClassNotDefined < StandardError; end
  class AccessedInvalidAttribute < StandardError; end
end
