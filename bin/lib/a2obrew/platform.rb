# encoding: utf-8

require_relative 'dotfile'
require_relative 'cli_base'
require_relative 'zip_uploader'

module A2OBrew
  class Platform < CLIBase
    desc 'deploy [input_dir]', 'deploy application stored in a directory'
    method_option :profile, aliases: '-p', desc: 'Profile name for Tombo Platform'
    def deploy(input_dir)
      d = Dotfile.new(options[:profile])
      Dir.mktmpdir do |tmp_dir|
        zip_path = File.join(tmp_dir, 'deploy.zip')
        ZipUploader.create_zip(zip_path, input_dir)
        ZipUploader.upload_zip(zip_path, d.developer_portal_uri)
      end
    end
  end
end
