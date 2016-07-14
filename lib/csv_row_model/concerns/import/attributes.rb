require 'csv_row_model/concerns/import/csv_string_model'
require 'csv_row_model/internal/import/attribute'

module CsvRowModel
  module Import
    module Attributes
      extend ActiveSupport::Concern
      include CsvStringModel

      included do
        self.column_names.each { |*args| define_attribute_method(*args) }
      end

      def attribute_objects
        @attribute_objects ||= begin
          csv_string_model.valid?
          _attribute_objects(csv_string_model.errors)
        end
      end

      # @return [Hash] a map of `column_name => format_cell(column_name, ...)`
      def formatted_attributes
        array_to_block_hash(self.class.column_names) { |column_name| attribute_objects[column_name].formatted_value }
      end

      # @return [Hash] a map of `column_name => original_attribute(column_name)`
      def original_attributes
        array_to_block_hash(self.class.column_names) { |column_name| original_attribute(column_name) }
      end

      # @return [Object] the column's attribute before override
      def original_attribute(column_name)
        attribute_objects[column_name].try(:value)
      end

      # return [Hash] a map changes from {.column}'s default option': `column_name -> [value_before_default, default_set]`
      def default_changes
        array_to_block_hash(self.class.column_names) { |column_name| attribute_objects[column_name].default_change }.delete_if {|k, v| v.blank? }
      end

      protected
      # to prevent circular dependency with csv_string_model
      def _attribute_objects(csv_string_model_errors={})
        array_to_block_hash(self.class.column_names) do |column_name|
          Attribute.new(column_name, source_attributes[column_name], csv_string_model_errors[column_name], self)
        end
      end

      class_methods do
        protected
        # See {Model#column}
        def column(column_name, options={})
          super
          define_attribute_method(column_name)
        end

        def merge_options(column_name, options={})
          original_options = columns[column_name]
          csv_string_model_class.add_type_validation(column_name, columns[column_name]) unless original_options[:validate_type]
          super
        end

        # Define default attribute method for a column
        # @param column_name [Symbol] the cell's column_name
        def define_attribute_method(column_name)
          return if method_defined? column_name
          csv_string_model_class.add_type_validation(column_name, columns[column_name])
          define_proxy_method(column_name) { original_attribute(column_name) }
        end
      end
    end
  end
end
