# this is the tab
module GSuiteAPI::Sheets
  class Sheet
    delegate :id, :service, to: :spreadsheet
    delegate :properties, to: :api_object

    attr_reader :name, :spreadsheet, :api_object

    BATCH_SIZE = 10000
    ELAPSED_MULTIPLIER = 1.5

    def initialize(spreadsheet:, name:, api_object:)
      @spreadsheet = spreadsheet
      @name = name
      @api_object = api_object
    end

    # ugh -- dirty
    def refresh!
      my_sheet_id = @api_object.properties.sheet_id
      spreadsheet.refresh
      @api_object = @spreadsheet.api_object.sheets.detect { |s| s.properties.sheet_id == my_sheet_id }
      @name = api_object.properties.title
      @a1_table = nil
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

    def table(range:)
      values = get(range: range).values
      headers = values.shift
      values.map { |row| Hash[headers.zip(row)] }
    end

    def set(range:, values:, value_input_option: 'USER_ENTERED')
      service.update_spreadsheet_value \
        id, range_with_name(range), { values: values },
        value_input_option: value_input_option
    end

    def upsert_table(values:, value_input_option:, extra_a1_note: nil)
      # touch up the headers
      set range: '1:1', values: [values.first], value_input_option: value_input_option

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
      column_count = values.map(&:count).max
      clear(range: "A2:#{column_name(column_count)}#{row_count}")

      # we don't need this if appending to tables
      row_delta = values.count - (row_count - 1)
      insert_rows(row_delta, start_index: row_count) if row_delta.positive?
      sleep 1 # allow time for row insert to settle

      # the tables inside of us may have changed
      refresh!

      if has_a1_table?
        # we need to append rows to the table too!
        current_table_rows = a1_table.range.end_row_index - 1

        if current_table_rows < values.count
          new_range = a1_table.range.dup
          new_range.end_row_index = values.count + 1
          new_range.end_column_index = column_count

          update_table_request = {
            update_table: {
              table: {
                table_id: a1_table.table_id,
                range: new_range
              },
              fields: "range"
            }
          }

          update_borders_request = {
            update_borders: {
              range: new_range,
              top: { style: "NONE" },
              bottom: { style: "NONE" },
              left: { style: "NONE" },
              right: { style: "NONE" },
              inner_horizontal: { style: "NONE" },
              inner_vertical: { style: "NONE" }
            }
          }

          service.batch_update_spreadsheet id, { requests: [update_table_request, update_borders_request] }

          sleep 1 * ELAPSED_MULTIPLIER # allow time for row insert to settle
        end
      end

      # since we are putting into a table in A1, start at A2
      start_row = 2
      # write data in batches, avoid append_cells, update ranges specifically
      values.each_slice(BATCH_SIZE).with_index do |value_slice, index|
        end_row = start_row + value_slice.size - 1
        update_range = "A#{start_row}:#{column_name(column_count)}#{end_row}"
        elapsed = Benchmark.realtime do
          service.update_spreadsheet_value \
            id, range_with_name(update_range), { values: value_slice },
            value_input_option: value_input_option,
            include_values_in_response: false
        end

        # udpate start_row for next batch
        start_row = start_row + value_slice.size
        # allow time for successive writes to settle
        sleep elapsed * ELAPSED_MULTIPLIER
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
      "'#{name}'!#{range}"
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

    def has_a1_table?
      a1_table.present?
    end

    def a1_table
      @a1_table ||= _a1_table if api_object.respond_to?(:tables)
    end

    def _a1_table
      api_object.tables&.detect { |table| table.range.start_column_index == 0 && table.range.start_row_index == 0 }
    end

    def column_name(int)
      name = 'A'
      (int - 1).times { name.succ! }
      name
    end
  end
end
