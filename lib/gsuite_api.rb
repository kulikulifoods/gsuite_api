require "gsuite_api/version"

# bare -- let other files cherry pick what they need
require "active_support"

# code
require "gsuite_api/drive"
require "gsuite_api/sheets"

module GSuiteAPI
  class << self
    def auth_client
      @auth_client ||= _auth_client
    end

    def map_nils_to_empty_strings(values)
      values.map! { |a| a.map! { |e| e.nil? ? '' : e } }
    end

    private

    def _auth_client
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

      auth_client
    end
  end
end
