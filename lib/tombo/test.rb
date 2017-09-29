# frozen_string_literal: true

require_relative 'dotfile'
require_relative 'cli_base'
require_relative '../a2obrew/util'

require 'httpclient'
require 'fileutils'

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
      rescue StandardError
        error_exit("Cannot connect to #{DEV_PORTAL_URI}")
      end

      # Check profile
      dotfile = Dotfile.new
      create_developer = false
      if dotfile.profile?(PROFILE)
        # Check https://developer.tombo.io/developer with profile
        begin
          outputs = []
          A2OBrew::Util.cmd_exec("tombocli developers show -p #{PROFILE} 2>/dev/null") do |output|
            outputs << output
          end
          JSON.parse(outputs.join(''))
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

        outputs = []
        begin
          A2OBrew::Util.cmd_exec("tombocli developers create -p #{PROFILE} --name '#{name}' --email '#{email}' --password '#{password}' --password-confirmation '#{password_confirmation}' --country-id #{country_id} --currency-id #{currency_id} --language-id #{LANGUAGE_ID} --time-zone-id #{time_zone_id} 2>/dev/null") do |output|
            outputs << output
          end
          created_developer = JSON.parse(outputs.join(''))
          developer_credential = created_developer['data']['attributes']['credential']
          # Create new profile on ~/.tombo/config with credential
          dotfile.set_profile(PROFILE, developer_portal_uri: DEV_PORTAL_URI,
                                       ssl_certificate_verify: false,
                                       compress_with_zopfli: false,
                                       developer_credential: developer_credential)
        rescue A2OBrew::CmdExecException, JSON::ParserError => e
          puts outputs.join('')
          puts e
          error_exit "Cannot create developer: #{name}"
        end
      end

      # Now we can access the platform server

      # Check we have already had a application which has the screen_name SCREEN_NAME
      # If exists, fetch the application_id.
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli applications index -p #{PROFILE} 2>/dev/null") do |output|
        outputs << output
      end

      application_id = nil
      begin
        applications = JSON.parse(outputs.join(''))['data']
        applications.each do |application|
          application_id = application['id'] if application['attributes']['screen_name'] == SCREEN_NAME
        end
      rescue JSON::ParserError
        puts "Cannot find application `#{SCREEN_NAME}`"
      end

      # If application_id is nil, create the application which has the screen_name SCREEN_NAME
      if application_id.nil?
        outputs = []
        begin
          A2OBrew::Util.cmd_exec("tombocli applications create -p #{PROFILE} --default-language-id #{LANGUAGE_ID} --screen-name #{SCREEN_NAME} 2>/dev/null") do |output|
            outputs << output
          end
        rescue A2OBrew::CmdExecException => e
          puts outputs.join('')
          puts e
          error_exit "Cannot create an application. Maybe the screen name `#{SCREEN_NAME}` is already taken."
        end

        begin
          application = JSON.parse(outputs.join(''))['data']
          application_id = application['id']
        rescue JSON::ParserError
          error_exit('Cannot create an application')
        end

        # Create application localize
        A2OBrew::Util.cmd_exec("tombocli application_localizes create -p #{PROFILE} --application-id #{application_id} --language-id #{LANGUAGE_ID} --name #{SCREEN_NAME} 2>/dev/null")
      end

      # Create application package
      package_path = 'test-package.zip'
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli application_versions package --source-directory #{source_directory} --package-path #{package_path} 2>/dev/null") do |output|
        outputs << output
      end

      # Create application version
      version = Time.now.strftime('%Y%m%d%H%M%S%3N') # msec
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli application_versions create -p #{PROFILE} --application-id #{application_id} --version #{version} --package-path #{package_path} 2>/dev/null") do |output|
        outputs << output
      end

      # remove temporary path
      FileUtils.rm(package_path)

      application_version_id = nil
      begin
        application_version = JSON.parse(outputs.join(''))['data']
        application_version_id = application_version['id']
      rescue JSON::ParserError
        error_exit('Cannot create an application version')
      end

      # Set the application version latest
      A2OBrew::Util.cmd_exec("tombocli applications update -p #{PROFILE} --application-id #{application_id} --active-version-id #{application_version_id} 2>/dev/null")

      # Open the default browser to show
      system("open #{PLATFORM_URI}/#{SCREEN_NAME}")
    end

    GAMEPLUS_CONTENTS_CODE = 'GAMEPLUS_CONTENTS_CODE'
    GAMEPLUS_SCREEN_NAME = 'gptest'

    desc 'upload_gameplus', 'upload gameplus application into Tombo platform'
    def upload_gameplus(*source_directories) # rubocop:disable Metrics/AbcSize,PerceivedComplexity,MethodLength,CyclomaticComplexity
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
      rescue StandardError
        error_exit("Cannot connect to #{DEV_PORTAL_URI}")
      end

      # Check profile
      dotfile = Dotfile.new
      create_developer = false
      if dotfile.profile?(PROFILE)
        # Check https://developer.tombo.io/developer with profile
        begin
          outputs = []
          A2OBrew::Util.cmd_exec("tombocli developers show -p #{PROFILE} 2>/dev/null") do |output|
            outputs << output
          end
          JSON.parse(outputs.join(''))
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

        outputs = []
        begin
          A2OBrew::Util.cmd_exec("tombocli developers create -p #{PROFILE} --name '#{name}' --email '#{email}' --password '#{password}' --password-confirmation '#{password_confirmation}' --country-id #{country_id} --currency-id #{currency_id} --language-id #{LANGUAGE_ID} --time-zone-id #{time_zone_id} 2>/dev/null") do |output|
            outputs << output
          end
          created_developer = JSON.parse(outputs.join(''))
          developer_credential = created_developer['data']['attributes']['credential']
          # Create new profile on ~/.tombo/config with credential
          dotfile.set_profile(PROFILE, developer_portal_uri: DEV_PORTAL_URI,
                                       ssl_certificate_verify: false,
                                       compress_with_zopfli: false,
                                       developer_credential: developer_credential)
        rescue A2OBrew::CmdExecException, JSON::ParserError => e
          puts outputs.join('')
          puts e
          error_exit "Cannot create developer: #{name}"
        end
      end

      # Now we can access the platform server

      # Check we have already had a gameplus application which has the gp_screen_name GAMEPLUS_SCREEN_NAME
      # If exists, fetch the application_id.
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli gp_applications index -p #{PROFILE} 2>/dev/null") do |output|
        outputs << output
      end

      gp_application_id = nil
      begin
        gp_applications = JSON.parse(outputs.join(''))['data']
        gp_applications.each do |gp_application|
          gp_application_id = gp_application['id'] if gp_application['attributes']['gp_screen_name'] == GAMEPLUS_SCREEN_NAME
        end
      rescue JSON::ParserError
        puts "Cannot find gp_application `#{GAMEPLUS_SCREEN_NAME}`"
      end

      # If gp_application_id is nil, create the gp_application which has the gp_screen_name GAMEPLUS_SCREEN_NAME
      if gp_application_id.nil?
        outputs = []
        begin
          A2OBrew::Util.cmd_exec("tombocli gp_applications create -p #{PROFILE} --gp-contents-code #{GAMEPLUS_CONTENTS_CODE} --gp-screen-name #{GAMEPLUS_SCREEN_NAME} 2>/dev/null") do |output|
            outputs << output
          end
        rescue A2OBrew::CmdExecException => e
          puts outputs.join('')
          puts e
          error_exit "Cannot create an gp_application. Maybe the gameplus screen name `#{GAMEPLUS_SCREEN_NAME}` is already taken."
        end

        begin
          gp_application = JSON.parse(outputs.join(''))['data']
          gp_application_id = gp_application['id']
        rescue JSON::ParserError
          error_exit('Cannot create an gp_application')
        end
      end

      # Create gp_application package
      package_path = 'test-package.zip'
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli gp_application_versions package --source-directory #{source_directory} --package-path #{package_path} 2>/dev/null") do |output|
        outputs << output
      end

      # Create gp_application version
      version = Time.now.strftime('%Y%m%d%H%M%S%3N') # msec
      outputs = []
      A2OBrew::Util.cmd_exec("tombocli gp_application_versions create -p #{PROFILE} --gp-application-id #{gp_application_id} --version #{version} --package-path #{package_path} 2>/dev/null") do |output|
        outputs << output
      end

      # remove temporary path
      FileUtils.rm(package_path)

      gp_application_version_id = nil
      begin
        gp_application_version = JSON.parse(outputs.join(''))['data']
        gp_application_version_id = gp_application_version['id']
      rescue JSON::ParserError
        error_exit('Cannot create an gp_application version')
      end

      # Set the gp_application version latest
      A2OBrew::Util.cmd_exec("tombocli gp_applications update -p #{PROFILE} --gp-application-id #{gp_application_id} --gp-active-version-id #{gp_application_version_id} 2>/dev/null")

      # Open the default browser to show
      system("open #{PLATFORM_URI}/_gameplus/#{GAMEPLUS_SCREEN_NAME}")
    end
  end
end
