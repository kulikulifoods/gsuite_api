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
    @api_object ||= service.get_file id, fields: "id,name,kind,parents", supports_all_drives: true
    end

    def copy(name:, parent: nil, description: nil)
      params = { name: name }

      params[:parents] = [parent] if parent.present?
      params[:description] = description if description.present?

      service.copy_file id, params, fields: "id,name", supports_all_drives: true
    end
  end
end
