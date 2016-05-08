# encoding: utf-8

require_relative 'dotfile'
require_relative 'cli_base'
require_relative 'zip_creator'

module A2OBrew
  class Platform < CLIBase
    def initialize(*args)
      super

      @dotfile = Dotfile.new(options[:profile])
    end

    desc 'deploy [input_dir] [application_version_id]', 'deploy application stored in a directory'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def deploy(input_dir, application_version_id)
      Dir.mktmpdir do |tmp_dir|
        zip_path = File.join(tmp_dir, 'deploy.zip')
        ZipCreator.create_zip(zip_path, input_dir)
        create_application_archive(application_version_id, zip_path)
      end
    end

    private

    def request(method, path, query = nil, body = nil, extheader = {})
      cl = HTTPClient.new
      cl.ssl_config.verify_mode = nil unless @dotfile.ssl_certificate_verify
      # cl.debug_dev = STDOUT

      header_with_credential = credential_headers(extheader)
      cl.request(method, @dotfile.developer_portal_uri(path), query, body, header_with_credential)
    end

    def credential_headers(base_headers, _content_type = 'application/json')
      now = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
      headers = base_headers.dup
      headers.merge('Authorization' => authorization_header,
                    'X-Tombo-Date' => now)
    end

    def authorization_header
      cred_id = @dotfile.developer_credential_id
      "TOMBO1-HMAC-SHA256 Credential=#{cred_id}/date/tombo1, SignedHeaders=#{signed_headers}, Signature=#{signature}"
    end

    def signed_headers
      'FIXME'
    end

    def signature
      'FIXME'
    end

    def create_application_archive(application_version_id, payload_path)
      File.open(payload_path) do |payload|
        body = {
          application_version_id: application_version_id,
          payload: payload
        }
        response = request('POST', '/application_archives.json', nil, body)
        p response
      end
    end
  end
end
