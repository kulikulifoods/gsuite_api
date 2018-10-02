require "base64"
require "active_support/core_ext/object/blank"

module GSuiteAPI
  module DumpCredentials
    def self.dump
      if ENV["GOOGLE_CREDENTIALS_BASE64"].present? &&
          ENV["GOOGLE_APPLICATION_CREDENTIALS"].present?
        unless File.exist? ENV["GOOGLE_APPLICATION_CREDENTIALS"]
          credentials = Base64.decode64 ENV["GOOGLE_CREDENTIALS_BASE64"]
          begin
            File.write ENV["GOOGLE_APPLICATION_CREDENTIALS"], credentials
          rescue SystemCallError => e
            warn "Unable to dump credentials from ENV: #{e}"
          end
        end
      end
    end
  end
end
