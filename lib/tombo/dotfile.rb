# frozen_string_literal: true

require 'inifile'
require 'highline'

module Tombo
  class Dotfile
    def initialize(profile_name = nil, base_path = nil)
      @base_path = checked_base_path(base_path)

      @section = Dotfile.profile_to_section(profile_name)
      @config_path = Dotfile.checked_config_path(File.join(@base_path, 'config'))

      @ini_file = IniFile.load(@config_path)

      raise "Invalid profile #{profile_name}" unless @ini_file.has_section?(@section)

      @config = @ini_file[@section]
    end

    def developer_portal_uri(path)
      @config['developer_portal_uri'] + path
    end

    def developer_credential
      @config['developer_credential']
    end

    def ssl_certificate_verify?
      if @config.key?('ssl_certificate_verify')
        @config['ssl_certificate_verify']
      else
        # default true
        true
      end
    end

    def compress_with_zopfli?
      if @config.key?('compress_with_zopfli')
        @config['compress_with_zopfli']
      else
        # default true
        true
      end
    end

    def profile?(profile_name)
      @ini_file.has_section?(Dotfile.profile_to_section(profile_name))
    end

    def set_profile(profile_name, config)
      merged_config = Dotfile.default_config.merge(config)
      @ini_file[Dotfile.profile_to_section(profile_name)] = merged_config
      @ini_file.save
    end

    def delete_profile(profile_name)
      @ini_file.delete_section(profile_name)
    end

    def self.profile_to_section(profile_name)
      if profile_name.nil?
        'default'
      else
        "profile #{profile_name}"
      end
    end

    def checked_base_path(base_path)
      if base_path.nil?
        base_path = File.join(ENV['HOME'], '.tombo')
        FileUtils.mkdir(base_path) unless File.exist?(base_path)
      end

      raise "Cannot file base_path #{base_path}" unless File.exist?(base_path)
      base_path
    end

    def self.checked_config_path(config_path)
      generate_config(config_path) unless File.exist?(config_path)
      config_path
    end

    def self.generate_config(config_path)
      puts "Generate #{config_path} to save platform informations"

      ini_file = IniFile.new
      ini_file['default'] = default_config
      ini_file.save(filename: config_path)
    end

    def self.default_config
      {
        developer_portal_uri: 'https://developer.tombo.io',
        developer_credential: 'PLEASE_SET_CREDENTIAL',
        ssl_certificate_verify: true,
        compress_with_zopfli: true
      }
    end
  end
end
