# frozen_string_literal: true

require "google/apis/drive_v3"

require "gsuite_api/drive/file"

module GSuiteAPI
  module Drive
    class << self
      def file_by_id(id)
        File.new service: service, id: id
      end

      def service
        @service || _service
      end

      def _service
        service = Google::Apis::DriveV3::DriveService.new
        service.authorization = GSuiteAPI.auth_client
        service
      end
    end
  end
end
