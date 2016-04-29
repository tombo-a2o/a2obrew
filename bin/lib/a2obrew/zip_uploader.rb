require 'zip'
require 'httpclient'

module A2OBrew
  class ZipUploader
    def self.create_zip(output_zip_path, input_directory_path)
      Zip.sort_entries = true
      Zip.default_compression = Zlib::BEST_COMPRESSION
      Zip::File.open(output_zip_path, Zip::File::CREATE) do |zip|
        recursive_zip_add(zip, input_directory_path, '')
      end
    end

    def self.recursive_zip_add(zip, input_dir_path, output_dir_path)
      raise "#{input_dir_path} is not directory" unless File.directory?(input_dir_path)
      Dir.foreach(input_dir_path) do |file_name|
        next if file_name == '.' || file_name == '..'
        input_path = File.join(input_dir_path, file_name)
        output_path = output_dir_path.empty? ? file_name : File.join(output_dir_path, file_name)

        if File.directory?(input_path)
          zip.mkdir(output_path)
          recursive_zip_add(zip, input_path, output_path)
        else
          zip.get_output_stream(output_path) do |f|
            f.write(File.read(input_path))
          end
        end
      end
    end

    def self.upload_zip(input_path, endpoint_uri)
      http_client = HTTPClient.new
      File.open(input_path) do |file|
        body = {
          'contents_archive' => file
        }
        http_client.post(endpoint_uri, body)
      end
    end
  end
end
