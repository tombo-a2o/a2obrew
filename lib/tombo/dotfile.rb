# frozen_string_literal: true
require 'inifile'
require 'highline'

module Tombo
  class Dotfile
    def initialize(profile_name = nil, base_path = nil)
      @base_path = checked_base_path(base_path)

      section = profile_name.nil? ? 'default' : "profile #{profile_name}"
      @config_path = checked_config_path(File.join(@base_path, 'config'))

      ini_file = IniFile.load(@config_path)

      raise "Invalid profile #{profile_name}" unless ini_file.has_section?(section)

      @config = ini_file[section]
    end

    def developer_portal_uri(path)
      @config['developer_portal_uri'] + path
    end

    def developer_credential
      @config['developer_credential']
    end

    def ssl_certificate_verify?
      # default true
      @config['ssl_certificate_verify'] != 'false'
    end

    def compress_with_zopfli?
      # default true
      @config['compress_with_zopfli'] != 'false'
    end

    private

    def checked_base_path(base_path)
      if base_path.nil?
        base_path = File.join(ENV['HOME'], '.tombo')
        FileUtils.mkdir(base_path) unless File.exist?(base_path)
      end

      raise "Cannot file base_path #{base_path}" unless File.exist?(base_path)
      base_path
    end

    def checked_config_path(config_path)
      generate_config(config_path) unless File.exist?(config_path)
      config_path
    end

    def generate_config(config_path)
      puts "Generate #{config_path} to save platform informations"
      hl = HighLine.new
      dev_portal_uri = hl.ask('Developer portal URI:') do |q|
        q.default = 'https://developer.tombo.io'
      end
      dev_credential = hl.ask('Developer credential id:')

      File.open(config_path, 'w') do |f|
        f.puts <<EOF
[default]
developer_portal_uri = #{dev_portal_uri}
developer_credential = #{dev_credential}
ssl_certificate_verify = true
compress_with_zopfli = false
EOF
      end
    end
  end
end
