require 'thor'
require 'json'
require 'logger'
require_relative '../a2obrew/util'

module Tombo
  module Logger
    def self.logger
      # rubocop:disable Style/ClassVars
      @@logger ||= ::Logger.new(STDERR)
    end
  end

  class CLIBase < Thor
    def initialize(*args)
      super

      @dotfile = Dotfile.new(options[:profile])
    end

    def self.puts_commands
      commands.each do |command|
        puts command[0]
      end
      exit(0)
    end

    private

    def error_exit(message, exit_status = 1)
      A2OBrew::Util.error_exit(message, @current_command, exit_status)
    end

    def request(method, path, query = nil, body = nil, extheader = {})
      cl = HTTPClient.new
      cl.ssl_config.verify_mode = nil unless @dotfile.ssl_certificate_verify
      # cl.debug_dev = STDOUT

      header_with_credential = credential_headers(extheader)
      response = cl.request(method, @dotfile.developer_portal_uri(path), query, body, header_with_credential)
      json = JSON.parse(response.body)
      if json['errors'] && !json['errors'].empty?
        puts 'API error'
        json['errors'].each do |error|
          puts error
        end
        error_exit('API failed')
      end

      json
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

    def create_uploaded_file(payload_path)
      json = nil
      File.open(payload_path) do |payload|
        body = {
          'uploaded_file[payload]' => payload
        }
        json = request('POST', '/uploaded_files.json', nil, body)
      end

      d = json['data']

      raise 'Cannot upload file' unless d['type'] == 'uploaded_files' && d['id']
      raise 'Uploaded file may be broken' if d['attributes']['size'] != File.size(payload_path)

      d['id']
    end

    def output(data, color = true)
      if STDOUT.tty? && color
        require 'json_color'
        puts JsonColor.colorize(JSON.pretty_generate(data))
      else
        puts JSON.pretty_generate(data)
      end
    end
  end
end
