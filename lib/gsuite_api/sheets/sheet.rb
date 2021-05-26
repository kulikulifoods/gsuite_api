require 'active_support/core_ext/module/delegation'

module GSuiteAPI::Sheets
  class Sheet
    delegate :id, :service, to: :spreadsheet
    attr_reader :name, :spreadsheet, :api_object

    def initialize(spreadsheet:, name:, api_object:)
      @spreadsheet = spreadsheet
      @name = name
      @api_object = api_object
    end

    def row_count
      api_object.properties.grid_properties.row_count
    end

    def column_count
      api_object.properties.grid_properties.column_count
    end

    # gets the number of rows in the first column's table
    def table_row_count
      get(range: 'A:A').values.count
    end

    def get(range:)
      service.get_spreadsheet_values(id, range_with_name(range))
    end

    # only supports appending to the table in A1
    def append(values:, value_input_option:)
      named_range = range_with_name 'A1'
      service.append_spreadsheet_value \
        id, named_range, { values: values },
        value_input_option: value_input_option
    end

    def replace_table(values:, value_input_option:)
      current_size = table_row_count - 1
      if current_size.zero?
        # this means the table is actually empty, so replacing data is going
        # to have weird effects anyways. so in this case, it's safe to use the
        # row count.
        current_size = row_count - 1
      end

      needed_size = values.count
      row_delta = needed_size - current_size

      if row_delta.negative?
        delete_rows(row_delta.abs, start_index: 1)
      elsif row_delta.positive? && (needed_size > (row_count - 1))
        insert_rows(row_delta, start_index: 2)
      end

      # write data
      service.update_spreadsheet_value \
        id, range_with_name('A2'), { values: values },
        value_input_option: value_input_option
    end

    def upsert_table(values:, value_input_option:)
      # touch up the headers
      service.update_spreadsheet_value \
        id, range_with_name('1:1'), { values: [values[0]] },
        value_input_option: value_input_option

      # replace the data
      replace_table \
        values: values[1..-1], value_input_option: value_input_option

      add_a1_note(note: "Data Vortex updated at #{Time.current}")
    end

    def clear(range:)
      service.clear_values(id, range_with_name(range))
    end

    def modify(insert_or_delete, rows_or_colums, number, start_index:,
               inherit_from_before: true)
      request = {}

      insert_or_delete_key = {
        insert: :insert_dimension,
        delete: :delete_dimension,
      }.fetch(insert_or_delete)

      dimension = {
        rows: 'ROWS',
        columns: 'COLUMNS',
      }.fetch(rows_or_colums)

      request[insert_or_delete_key] = {
        range: {
          sheet_id: api_object.properties.sheet_id,
          dimension: dimension,
          start_index: start_index,
          end_index: start_index + number,
        },
        inherit_from_before: inherit_from_before,
      }

      update = { requests: [request] }
      service.batch_update_spreadsheet id, update, {}
    end

    def delete_rows(number, start_index:)
      modify :delete, :rows, number, start_index: start_index
    end

    def insert_rows(number, start_index:)
      modify :insert, :rows, number, start_index: start_index
    end

    def crop_header
      num_cols = get(range: 'A1:1').values.first.count
      update = { requests: [{
        update_sheet_properties: {
          properties: {
            sheet_id: api_object.properties.sheet_id,
            grid_properties: {
              row_count: 1,
              column_count: num_cols,
            },
          },
          fields: 'gridProperties(rowCount,columnCount)',
        },
      }] }
      service.batch_update_spreadsheet(id, update, {})
    end

    def range_with_name(range)
      "#{escaped_name}!#{range}"
    end

    # I thought we might need to be able to escape the name?  Guess not...
    def escaped_name
      # @escaped_name ||= CGI.escape(name)
      name
    end

    def add_a1_note(note:)
      add_note = {
        update_cells: {
          start: {
            sheet_id: api_object.properties.sheet_id,
            row_index: 0,
            column_index: 0,
          },
          rows: [
            {
              values: [
                {
                  note: note,
                }
              ],
            }
          ],
          fields: 'note',
        },
      }

      update = { requests: [add_note] }

      service.batch_update_spreadsheet(id, update, {})
    end

    def inspect
      format '#<%p id=%p title=%p sheet=%p>', \
             self.class, id, spreadsheet.title, name
    end
  end
end
