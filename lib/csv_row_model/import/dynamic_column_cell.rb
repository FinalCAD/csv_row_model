module CsvRowModel
  module Import
    class DynamicColumnCell < CsvRowModel::Model::DynamicColumnCell
      attr_reader :source_headers, :source_cells

      def initialize(column_name, source_headers, source_cells, row_model)
        @source_headers = source_headers
        @source_cells = source_cells
        super(column_name, row_model)
      end

      def unformatted_value
        formatted_cells.zip(formatted_headers).map do |formatted_cell, source_header|
          call_process_cell(formatted_cell, source_header)
        end
      end

      def formatted_cells
        source_cells.map.with_index do |source_cell, index|
          row_model.class.format_cell(source_cell, column_name, dynamic_column_index + index, row_model.context)
        end
      end

      def formatted_headers
        source_headers.map.with_index do |source_header, index|
          row_model.class.format_dynamic_column_header(source_header, column_name, dynamic_column_index, index, row_model.context)
        end
      end

      class << self
        def define_process_cell(row_model_class, column_name)
          super { |formatted_cell, source_header| formatted_cell }
        end
      end
    end
  end
end