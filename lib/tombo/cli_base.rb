# frozen_string_literal: true

require 'thor'
require 'json'
require 'logger'
require_relative 'dotfile'

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

      begin
        @dotfile = Dotfile.new(options[:profile])
      rescue => e
        error_exit(e.message)
      end
    end

    def self.puts_commands
      commands.each do |command|
        puts command[0]
      end
      exit(0)
    end

    private

    def error_exit(message, exit_status = 1)
      Logger.logger.error message
      exit exit_status
    end

    def request(method, path, query = nil, body = nil, extheader = {})
      cl = HTTPClient.new
      cl.ssl_config.verify_mode = nil unless @dotfile.ssl_certificate_verify?
      # cl.connect_timeout = 120.0
      # cl.debug_dev = STDOUT

      header_with_credential = credential_headers(extheader)
      response = cl.request(method, @dotfile.developer_portal_uri(path), query, body, header_with_credential)

      begin
        json = JSON.parse(response.body)
      rescue JSON::ParserError
        # All API should respond with JSON
        Logger.logger.error 'API Response is not JSON:'
        Logger.logger.error response.body
        error_exit('API failed')
      end

      if (json['errors'] && !json['errors'].empty?) || response.status != 200
        # TODO: Handle response.status == 401 and tell what to do
        Logger.logger.error 'API error'
        json['errors'].each do |error|
          Logger.logger.error error
        end
        puts json
        exit 1
      end

      json
    end

    def credential_headers(base_headers)
      headers = base_headers.dup
      headers.merge('X-Tombo-Authorization' => authorization_header)
    end

    def authorization_header
      cred = @dotfile.developer_credential
      "TOMBO1-CREDENTIAL #{cred}"
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

    def output(data, color = false)
      if STDOUT.tty? && color
        require 'json_color'
        puts JsonColor.colorize(JSON.pretty_generate(data))
      else
        puts JSON.pretty_generate(data)
      end
    end
  end
end
