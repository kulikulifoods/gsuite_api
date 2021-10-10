# this is the file
module GSuiteAPI::Sheets
  class Spreadsheet
    attr_reader :service, :id
    def initialize(service:, id:)
      @service = service
      @id = id
    end

    def [](query)
      sheet = sheets.detect { |s| s.properties.title == query }
      if sheet
        Sheet.new spreadsheet: self, name: query, api_object: sheet
      end
    end

    def sheets
      api_object.sheets
    end

    def api_object
      @api_object ||= fresh_api_object
    end

    def refresh
      @api_object = fresh_api_object
      self
    end

    def title
      api_object.properties.title
    end

    def delete(sheet_ids:)
      requests = Array(sheet_ids).map do |sheet_id|
        { delete_sheet: { sheet_id: sheet_id } }
      end

      service.batch_update_spreadsheet id, { requests: requests }, {}
      refresh
      true
    end

    def duplicate(from:, to:)
      request = { duplicate_sheet: {
        source_sheet_id: self[from].properties.sheet_id,
        new_sheet_name: to,
      } }

      service.batch_update_spreadsheet id, { requests: [request] }, {}
      refresh
      true
    end

    def inspect
      format("\#<%p id=%p title=%p>", self.class, id, title)
    end

    private

    def fresh_api_object
      service.get_spreadsheet id
    end
  end
end
