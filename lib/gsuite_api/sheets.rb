require "google/apis/sheets_v4"

require "gsuite_api/sheets/spreadsheet"
require "gsuite_api/sheets/sheet"

module GSuiteAPI
  module Sheets
    class << self
      def by_id(id)
        Spreadsheet.new service: service, id: id
      end

      def sheet(id:, name:)
        by_id(id)[name]
      end

      def service
        @service || _service
      end

      def _service
        service = Google::Apis::SheetsV4::SheetsService.new
        service.authorization = GSuiteAPI.auth_client
        service.request_options.timeout_sec = 120
        service.request_options.open_timeout_sec = 60
        service
      end
    end
  end
end
