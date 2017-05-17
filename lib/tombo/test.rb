# frozen_string_literal: true

require_relative 'dotfile'
require_relative 'cli_base'
require_relative '../a2obrew/util'

require 'httpclient'

module Tombo
  class Test < CLIBase
    PROFILE = 'test-platform'
    LANGUAGE_ID = 14 # ja
    SCREEN_NAME = 'test'
    HOST = '192.168.99.100'
    PLATFORM_URI = "https://#{HOST}"
    DEV_PORTAL_URI = "https://#{HOST}:8002"

    desc 'upload', 'upload application into Tombo platform'
    def upload(*source_directories) # rubocop:disable Metrics/AbcSize,PerceivedComplexity,MethodLength,CyclomaticComplexity
      # rubocop: disable Metrics/LineLength

      # Check source_directory
      error_exit('Specify source directory to be uploaded') if source_directories.length != 1
      source_directory = source_directories[0]
      application_html_path = File.join(source_directory, 'application', 'application.html')
      unless File.file?(application_html_path)
        error_exit('Cannot find application.html')
      end

      # Check https connection
      begin
        Timeout.timeout(1) do
          cl = HTTPClient.new
          cl.ssl_config.verify_mode = nil
          r = cl.get(DEV_PORTAL_URI)
          raise unless HTTP::Status.successful?(r.status)
        end
      rescue
        error_exit("Cannot connect to #{DEV_PORTAL_URI}")
      end

      # Check profile
      dotfile = Dotfile.new
      create_developer = false
      if dotfile.profile?(PROFILE)
        # Check https://developer.tombo.io/developer with profile
        begin
          lines = []
          A2OBrew::Util.cmd_exec("tombocli developers show -p #{PROFILE} 2>/dev/null") do |line|
            lines << line
          end
          JSON.parse(lines.join("\n"))
        rescue A2OBrew::CmdExecException, JSON::ParserError
          puts '`tombocli developers show` fails.'
          dotfile.delete_profile(PROFILE)
          create_developer = true
        end
      else
        create_developer = true
      end

      if create_developer
        # Create new developer, get tokens and set it into ~/.tombo/config

        # Create new profile on ~/.tombo/config
        dotfile.set_profile(PROFILE, developer_portal_uri: DEV_PORTAL_URI,
                                     ssl_certificate_verify: false,
                                     compress_with_zopfli: false)

        # Create new developer
        name = 'a2obrew/tombocli integrated test'
        email = "#{Time.now.to_i}@tombo.io"
        password = 'testtest'
        password_confirmation = password
        country_id = 392 # JP
        currency_id = 392 # JPY
        time_zone_id = 280 # Asia/Tokyo

        lines = []
        begin
          A2OBrew::Util.cmd_exec("tombocli developers create -p #{PROFILE} --name '#{name}' --email '#{email}' --password '#{password}' --password-confirmation '#{password_confirmation}' --country-id #{country_id} --currency-id #{currency_id} --language-id #{LANGUAGE_ID} --time-zone-id #{time_zone_id} 2>/dev/null") do |line|
            lines << line
          end
          created_developer = JSON.parse(lines.join("\n"))
          developer_credential = created_developer['data']['attributes']['credential']
          # Create new profile on ~/.tombo/config with credential
          dotfile.set_profile(PROFILE, developer_portal_uri: DEV_PORTAL_URI,
                                       ssl_certificate_verify: false,
                                       compress_with_zopfli: false,
                                       developer_credential: developer_credential)
        rescue A2OBrew::CmdExecException, JSON::ParserError => e
          puts lines
          puts e
          error_exit "Cannot create developer: #{name}"
        end
      end

      # Now we can access the platform server

      # Check we have already had a application which has the screen_name SCREEN_NAME
      # If exists, fetch the application_id.
      lines = []
      A2OBrew::Util.cmd_exec("tombocli applications index -p #{PROFILE} 2>/dev/null") do |line|
        lines << line
      end

      application_id = nil
      begin
        applications = JSON.parse(lines.join("\n"))['data']
        applications.each do |application|
          application_id = application['id'] if application['attributes']['screen_name'] == SCREEN_NAME
        end
      rescue JSON::ParserError
        puts "Cannot find application `#{SCREEN_NAME}`"
      end

      # If application_id is nil, create the application which has the screen_name SCREEN_NAME
      if application_id.nil?
        lines = []
        begin
          A2OBrew::Util.cmd_exec("tombocli applications create -p #{PROFILE} --default-language-id #{LANGUAGE_ID} --screen-name #{SCREEN_NAME} 2>/dev/null") do |line|
            lines << line
          end
        rescue A2OBrew::CmdExecException => e
          puts lines
          puts e
          error_exit "Cannot create an application. Maybe the screen name `#{SCREEN_NAME}` is already taken."
        end

        begin
          application = JSON.parse(lines.join("\n"))['data']
          application_id = application['id']
        rescue JSON::ParserError
          error_exit('Cannot create an application')
        end

        # Create application localize
        A2OBrew::Util.cmd_exec("tombocli application_localizes create -p #{PROFILE} --application-id #{application_id} --language-id #{LANGUAGE_ID} --name #{SCREEN_NAME} 2>/dev/null") do |line|
        end
      end

      # Create application version
      version = Time.now.strftime('%Y%m%d%H%M%S%3N') # msec
      lines = []
      A2OBrew::Util.cmd_exec("tombocli application_versions create -p #{PROFILE} --application-id #{application_id} --version #{version} --source-directory #{source_directory} 2>/dev/null") do |line|
        lines << line
      end

      application_version_id = nil
      begin
        application_version = JSON.parse(lines.join("\n"))['data']
        application_version_id = application_version['id']
      rescue JSON::ParserError
        error_exit('Cannot create an application version')
      end

      # Set the application version latest
      A2OBrew::Util.cmd_exec("tombocli applications update -p #{PROFILE} --application-id #{application_id} --active-version-id #{application_version_id} 2>/dev/null") do |line|
      end

      # Open the default browser to show
      system("open #{PLATFORM_URI}/#{SCREEN_NAME}")
    end
  end
end
