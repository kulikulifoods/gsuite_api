require "google/apis/sheets_v4"

module GSuiteAPI
  module Sheets
    class << self
      def by_id(id)
        Spreadsheet.new service: service, id: id
      end

      def service
        @service || _service
      end

      def _service
        # Initialize the API
        scopes = [
          "https://www.googleapis.com/auth/drive",
          "https://www.googleapis.com/auth/spreadsheets",
        ]

        authorization = Google::Auth.get_application_default scopes

        # okay, now we have service account, become the user
        auth_client = authorization.dup
        auth_client.sub = ENV["GSUITE_USER"]
        auth_client.fetch_access_token!

        service = Google::Apis::SheetsV4::SheetsService.new
        service.authorization = auth_client

        service
      end
    end
  end
end
