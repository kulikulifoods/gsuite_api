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
      @api_object ||= service.get_spreadsheet id
    end

    def title
      api_object.properties.title
    end

    def inspect
      format("\#<%p id=%p title=%p>", self.class, id, title)
    end
  end
end
