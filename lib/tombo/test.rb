# frozen_string_literal: true

require_relative 'dotfile'
require_relative 'cli_base'
require_relative '../a2obrew/util'

module Tombo
  class Test < CLIBase
    PROFILE = 'test-platform'
    LANGUAGE_ID = 14 # ja
    SCREEN_NAME = 'test'
    DEV_PORTAL_URI = 'https://192.168.99.100:8002'

    desc 'upload', 'upload application into Tombo platform'
    def upload(*_proj_names) # rubocop:disable Metrics/AbcSize,PerceivedComplexity,MethodLength
      # rubocop: disable Metrics/LineLength
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
                                     ssl_certificate_verify: false)

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
          developer_credential = created_developer['data']['attributes']['developer_credential']['secret']
          # Create new profile on ~/.tombo/config with credential
          dotfile.set_profile(PROFILE, developer_portal_uri: DEV_PORTAL_URI,
                                       ssl_certificate_verify: false,
                                       developer_credential: developer_credential)
        rescue A2OBrew::CmdExecException, JSON::ParserError => e
          puts lines
          puts e
          error_exit "Cannot create developer: #{name}"
        end
      end

      # Now we can access the platform server
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

      if application_id.nil?
        lines = []
        A2OBrew::Util.cmd_exec("tombocli applications create -p #{PROFILE} --default-language-id #{LANGUAGE_ID} --screen-name #{SCREEN_NAME} 2>/dev/null") do |line|
          lines << line
        end

        begin
          application = JSON.parse(lines.join("\n"))['data']
          application_id = application['id']
        rescue JSON::ParserError
          error_exit('Cannot create an application')
        end
      end

      puts application_id
    end
  end
end
