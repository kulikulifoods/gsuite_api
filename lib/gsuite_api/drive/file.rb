# frozen_string_literal: true

module GSuiteAPI::Drive
  class File
    attr_reader :service, :id
    delegate :name, :kind, :parents, to: :api_object
    def initialize(service:, id:)
      @service = service
      @id = id
    end

    def api_object
      @api_object ||= service.get_file id, fields: "id,name,kind,parents"
    end

    def copy(new_name)
      service.copy_file id, { name: new_name }, fields: "id,name"
    end
  end
end
