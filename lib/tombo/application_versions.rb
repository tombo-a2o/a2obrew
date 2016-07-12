# encoding: utf-8

require 'json'
require_relative 'dotfile'
require_relative 'cli_base'
require_relative 'zip_creator'

module Tombo
  class ApplicationVersions < CLIBase
    desc 'create [application_id] [version] [input_dir]', 'deploy application stored in a directory'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def create(application_id, version, input_dir)
      index_html = 'application/application.html'
      error_exit("#{input_dir} must contain #{index_html}") unless File.file?(File.join(input_dir, index_html))

      Dir.mktmpdir do |tmp_dir|
        zip_path = File.join(tmp_dir, 'deploy.zip')
        ZipCreator.create_zip(zip_path, input_dir)
        uploaded_file_id = create_uploaded_file(zip_path)

        create_application_version(application_id, version, uploaded_file_id)
      end
    end

    private

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
