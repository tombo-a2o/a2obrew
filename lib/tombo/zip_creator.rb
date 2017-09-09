# frozen_string_literal: true

require 'zip'
require 'find'
require 'httpclient'

module Tombo
  class ZipCreator
    def self.create_zip(output_zip_path, input_directory_path, use_zopfli)
      Zip.sort_entries = true
      Zip.default_compression = Zlib::BEST_COMPRESSION
      Logger.logger.info "Create application zip on #{output_zip_path}"
      Zip::File.open(output_zip_path, Zip::File::CREATE) do |zip|
        recursive_zip_add(zip, input_directory_path, '', use_zopfli)
      end
      Logger.logger.info "Finish creation of #{output_zip_path}"
      Logger.logger.info "#{output_zip_path} size: #{File.size(output_zip_path)}"
    end

    def self.recursive_zip_add(zip, input_dir_path, output_dir_path, use_zopfli)
      raise "#{input_dir_path} is not directory" unless File.directory?(input_dir_path)
      Dir.foreach(input_dir_path) do |file_name|
        next if ['.', '..'].include?(file_name)
        input_path = File.join(input_dir_path, file_name)
        output_path = output_dir_path.empty? ? file_name : File.join(output_dir_path, file_name)

        if File.directory?(input_path)
          zip.mkdir(output_path)
          recursive_zip_add(zip, input_path, output_path, use_zopfli)
        else
          zip.get_output_stream(output_path) do |f|
            Logger.logger.info "Add #{output_path}"
            f.write(File.read(input_path))
          end

          add_gzip_compressed(zip, input_path, output_path, use_zopfli)
        end
      end
    end

    def self.add_gzip_compressed(zip, input_path, output_path, use_zopfli)
      case File.extname(input_path).intern
      when :'.html', :'.js', :'.css', :'.mem', :'.wasm', :'.dat', :'.symbols'
        unless File.exist?("#{input_path}.gz")
          zip.get_output_stream("#{output_path}.gz") do |f|
            Logger.logger.info "Compress #{output_path}.gz"
            gzipped = if use_zopfli
                        `zopfli -c "#{input_path}"`
                      else
                        # Use fastest (worst) compression
                        `gzip -1 -c "#{input_path}"`
                      end
            Logger.logger.info "#{File.size(input_path)} => #{gzipped.size}"
            f.write(gzipped)
          end
        end
      end
    end

    def self.upload_zip(input_path, platform_uri)
      http_client = HTTPClient.new
      File.open(input_path) do |file|
        body = {
          'contents_archive' => file
        }
        http_client.post("#{platform_uri}/application_versions", body)
      end
    end
  end
end
