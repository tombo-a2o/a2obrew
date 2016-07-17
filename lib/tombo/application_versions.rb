# encoding: utf-8

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'
require_relative 'zip_creator'

module Tombo
  class ApplicationVersions < CLIBase

    desc 'index', 'application versions index'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def index
      json = request('GET', '/application_versions.json')

      d = json['data']

      raise 'Cannot get application versions index' if d.nil? || !d.is_a?(Array)

      output(json)
    end

    desc 'create', 'deploy application stored in a directory'
    method_option :application_id, desc: 'Target application ID', required: true
    method_option :version, desc: 'Version string', required: true
    method_option :source_directory, desc: 'Source directory', required: true
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def create
      application_id = options[:application_id]
      version = options[:version]
      input_dir = options[:source_directory]

      file_exists?(input_dir, 'application/application.html')
      file_exists?(input_dir, 'tombo/icon/icon-60.png')

      Dir.mktmpdir do |tmp_dir|
        zip_path = File.join(tmp_dir, 'deploy.zip')
        ZipCreator.create_zip(zip_path, input_dir)
        uploaded_file_id = create_uploaded_file(zip_path)

        create_application_version(application_id, version, uploaded_file_id)
      end
    end

    private

    def file_exists?(input_dir, path)
      error_exit("#{input_dir} must contain #{path}") unless File.file?(File.join(input_dir, path))
      true
    end

    def create_application_version(application_id, version, uploaded_file_id)
      body = {
        'application_version[application_id]' => application_id,
        'application_version[version]' => version,
        'application_version[uploaded_file_id]' => uploaded_file_id
      }
      json = request('POST', '/application_versions.json', nil, body)

      d = json['data']

      if d.nil? || d['type'] != 'application_versions' || d['id'].nil?
        raise 'Cannot create application version'
      end

      output(json)
    end
  end
end
