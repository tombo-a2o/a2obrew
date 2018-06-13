# frozen_string_literal: true

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'
require_relative 'zip_creator'

module Tombo
  class GpApplicationVersions < CLIBase
    desc 'index', 'gp_application versions index'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def index
      json = request('GET', '/gp_application_versions.json')

      d = json['data']

      raise 'Cannot get gp_application versions index' if d.nil? || !d.is_a?(Array)

      output(json)
    end

    desc 'create', 'deploy gp_application stored in a directory'
    method_option :gp_application_id, desc: 'Target gp_application ID', required: true
    method_option :version, desc: 'Version string', required: true
    method_option :package_path, desc: 'Package path', required: true
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def create
      gp_application_id = options[:gp_application_id]
      version = options[:version]
      package_path = options[:package_path]

      uploaded_file_id = create_uploaded_file(package_path)

      create_gp_application_version(gp_application_id, version, uploaded_file_id)
    end

    desc 'package', 'create gp_application package to deploy'
    method_option :source_directory, desc: 'Source directory', required: true
    method_option :package_path, desc: 'Output package path', required: true
    def package
      input_dir = options[:source_directory]
      package_path = options[:package_path]

      file_exists?(input_dir, 'application/application.html')
      file_exists?(input_dir, 'application/icon/icon-60.png')
      file_exists?(input_dir, 'tombo/icon/icon-60.png')
      file_exists?(input_dir, 'application/launch-image/launch-image-320x480.png')

      Dir.mktmpdir do |tmp_dir|
        zip_path = File.join(tmp_dir, 'deploy.zip')
        ZipCreator.create_zip(zip_path, input_dir, @dotfile.compress_with_zopfli?)
        FileUtils.move(zip_path, package_path)
      end
    end

    private

    def file_exists?(input_dir, path)
      error_exit("#{input_dir} must contain #{path}") unless File.file?(File.join(input_dir, path))
      true
    end

    def create_gp_application_version(gp_application_id, version, uploaded_file_id)
      body = {
        'gp_application_version[gp_application_id]' => gp_application_id,
        'gp_application_version[version]' => version,
        'gp_application_version[uploaded_file_id]' => uploaded_file_id
      }
      json = request('POST', '/gp_application_versions.json', nil, body)

      d = json['data']

      raise 'Cannot create gp_application version' if d.nil? || d['type'] != 'gp_application_versions' || d['id'].nil?

      output(json)
    end
  end
end
