# this is the tab
module GSuiteAPI::Sheets
  class Sheet
    delegate :id, :service, to: :spreadsheet
    delegate :properties, to: :api_object

    attr_reader :name, :spreadsheet, :api_object

    BATCH_SIZE = 10000

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

    def table_row_count
      first_column = get(range: 'A:A').values
      if first_column.present?
        first_column.index([]) || row_count
      else
        0
      end
    end

    def get(range:)
      service.get_spreadsheet_values(id, range_with_name(range))
    end

    def set(range:, values:, value_input_option: 'USER_ENTERED')
      service.update_spreadsheet_value \
        id, range_with_name(range), { values: values },
        value_input_option: value_input_option
    end

    def upsert_table(values:, value_input_option:, extra_a1_note: nil)
      # touch up the headers
      service.update_spreadsheet_value \
        id, range_with_name('1:1'), { values: [values[0]] },
        value_input_option: value_input_option

      # replace the data
      replace_table \
        values: values[1..-1], value_input_option: value_input_option

      # set a useful note
      note = "Data Vortex updated at #{Time.current}"
      if extra_a1_note.present?
        note += "\n\n#{extra_a1_note}"
      end

      add_a1_note note: note
    end

    def replace_table(values:, value_input_option:)
      clear(range: "A2:#{column_name(values.first.count)}#{row_count}")

      row_delta = values.count - (row_count - 1)
      insert_rows(row_delta, start_index: row_count) if row_delta.positive?

      # write data in batches
      values.each_slice(BATCH_SIZE).each do |value_slice|
        service.append_spreadsheet_value \
          id, range_with_name('A2'), { values: value_slice },
          value_input_option: value_input_option
      end
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
      service.batch_update_spreadsheet id, update
    end

    def delete_rows(number, start_index:)
      modify :delete, :rows, number, start_index: start_index
    end

    def insert_rows(number, start_index:)
      modify :insert, :rows, number, start_index: start_index
    end

    def range_with_name(range)
      "#{name}!#{range}"
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

      service.batch_update_spreadsheet(id, update, fields: nil, quota_user: nil, options: nil)
    end

    def inspect

      format '#<%p id=%p title=%p sheet=%p>', \
             self.class, id, spreadsheet.title, name
    end

    protected

    def column_name(int)
      name = 'A'
      (int - 1).times { name.succ! }
      name
    end
  end
end
