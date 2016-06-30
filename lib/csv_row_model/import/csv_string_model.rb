module CsvRowModel
  module Import
    module CsvStringModel
      extend ActiveSupport::Concern

      def valid?(*args)
        super
        call_wrapper = using_warnings? ? csv_string_model.method(:using_warnings) : ->(&block) { block.call }
        call_wrapper.call do
          csv_string_model.valid?(*args)
          errors.messages.merge!(csv_string_model.errors.messages.reject {|k, v| v.empty? })
          errors.empty?
        end
      end

      # @return [Import::CsvStringModel::Model] a model with validations related to csv_string_model (values are from format_cell)
      # @return [Import::CsvStringModel::Model] a model with validations related to csv_string_model (values are from format_cell)
      def csv_string_model
        @csv_string_model ||= begin
          cell_objects = _cell_objects
          formatted_hash = array_to_block_hash(self.class.column_names) { |column_name| cell_objects[column_name].formatted_value }
          self.class.csv_string_model_class.new(formatted_hash)
        end
      end

      protected
      def _original_attribute(column_name)
        csv_string_model.valid?
        return nil unless csv_string_model.errors[column_name].blank?
      end

      class_methods do
        # @return [Class] the Class with validations of the csv_string_model
        def csv_string_model_class
          @csv_string_model_class ||= inherited_custom_class(:csv_string_model_class, Model)
        end

        protected
        # Called to add validations to the csv_string_model_class
        def csv_string_model(&block)
          csv_string_model_class.class_eval(&block)
        end
      end

      class Model < OpenStruct
        include ActiveWarnings

        # Classes with a validations associated with them in csv_row_model/validators
        PARSE_VALIDATION_CLASSES = [Boolean, Integer, Float, Date, DateTime].freeze

        class << self
          # Adds the type validation based on :validate_type option
          def add_type_validation(column_name, options)
            return unless options[:validate_type]

            type = options[:type]
            raise ArgumentError.new("invalid :type given for :validate_type for: #{column_name}") unless PARSE_VALIDATION_CLASSES.include? type

            class_eval { validates column_name, :"#{type.name.underscore}_format" => true, allow_blank: true }
          end
        end
      end
    end
  end
end