# frozen_string_literal: true

class Object
  def ninja_escape
    to_s.gsub(/\$/, '$$').gsub(/ /, '$ ')
  end

  def quote
    "'#{self}'"
  end

  def shell_quote_escape
    # escape single-quote within single-quoted string
    # cf. http://stackoverflow.com/questions/1250079/how-to-escape-single-quotes-within-single-quoted-strings
    gsub(/'/, %('"'"'))
  end
end

module A2OBrew
  class Ninja
    def self.write_ninja_build(output_dir, name, builds, default_targets) # rubocop:disable Metrics/AbcSize
      Util.mkdir_p(output_dir)

      path = File.join(output_dir, "#{name}.ninja.build")
      File.open(path, 'w:UTF-8') do |f|
        rules.each do |r|
          f.puts "rule #{r[:rule_name]}"
          f.puts "  description = #{r[:description]}" if r[:description]
          f.puts "  deps = #{r[:deps]}" if r[:deps]
          f.puts "  depfile = #{r[:depfile]}" if r[:depfile]
          f.puts "  command = #{r[:command]}"
          f.puts ''
        end

        builds.each do |b|
          # escape inputs and outpus here
          inputs = b[:inputs].map(&:ninja_escape).join(" $\n    ")
          outputs = b[:outputs].map(&:ninja_escape).join(' ')
          f.puts "build #{outputs}: #{b[:rule_name]} #{inputs}"

          # build_variables should be escaped at caller
          build_variables = b[:build_variables] || []
          build_variables.each do |k, v|
            f.puts "  #{k} = #{v}"
          end
          f.puts ''
        end

        f.puts "default #{default_targets.map(&:ninja_escape).join(' ')}"
      end

      path
    end

    def self.rules # rubocop:disable Metrics/MethodLength
      swiftc_path = `xcrun --sdk iphoneos --find swiftc`.chomp
      iphone_sdk_path = `xcrun --sdk iphoneos --show-sdk-path`.chomp

      [
        {
          rule_name: 'cp_r',
          description: 'cp -r from ${in} to ${out}',
          command: 'cp -r ${in} ${out}'
        },
        {
          rule_name: 'ln_sf',
          description: 'ln -sf ${source} ${out} # ref. ${in}',
          command: 'ln -sf ${source} ${out}'
        },
        {
          rule_name: 'sed',
          description: 'sed from ${in} to ${out}',
          command: 'sed ${options} ${in} > ${out}'
        },
        {
          rule_name: 'rm',
          description: 'remove ${out}',
          command: 'rm ${out}'
        },
        {
          rule_name: 'xcodebuild',
          description: 'a2obrew xcodebuild at ${in}',
          command: 'cd ${in} && a2obrew xcodebuild -t ${a2o_target} --xcodeproj-target "${xcodeproj_target}"'
        },
        {
          rule_name: 'ibtool',
          description: 'ibtool ${in}',
          command: 'ibtool --errors --warnings --notices --module ${module_name} '\
                   '--target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text '\
                   '--compilation-directory `dirname ${temp_dir}` ${in} && '\
                   'ibtool --errors --warnings --notices --module ${module_name} '\
                   '--target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text '\
                   '--link ${resources_dir} ${temp_dir}'
        },
        {
          rule_name: 'ibtool2',
          description: 'ibtool ${in}',
          command: 'ibtool --errors --warnings --notices --module ${module_name} --target-device iphone '\
                   '--minimum-deployment-target 9.0 --output-format human-readable-text --compile ${out} ${in}'
        },
        {
          rule_name: 'image-convert',
          description: 'image convert ${in}',
          command: 'convert -resize ${width}x${height} ${in} ${out}'
        },
        {
          rule_name: 'audio-convert',
          description: 'audio convert ${in}',
          command: 'afconvert -f mp4f -d aac ${in} -o ${out}'
        },
        {
          rule_name: 'file_packager',
          description: 'execute file packager to ${target}',
          command: "python #{ENV['EMSCRIPTEN']}/tools/file_packager.py ${target} --lz4 --preload ${packager_target_dir}@/ "\
                   '--js-output=${js_output} --no-heap-copy ${options} --use-preload-plugins'
        },
        # NOTE: A2O_LIBBSD_HEADERS indicates <stdlib.h> loads <bsd/stdlib.h> too.
        {
          rule_name: 'cc',
          description: 'c/c++/obj-c compile ${source} to ${out}',
          deps: 'gcc',
          depfile: '${out}.d',
          command: 'a2o -MMD -MF ${out}.d -Wno-absolute-value ${cc_flags} ${file_cflags} '\
                   '-DA2O_LIBBSD_HEADERS -c ${source} -o ${out}'
        },
        {
          rule_name: 'swiftc',
          description: 'swift compile ${source} to ${out}',
          # FIXME: target should be changed
          command: "#{swiftc_path} -sdk #{iphone_sdk_path} -target armv7-apple-ios8.0 -emit-bc ${source} -o ${out}"
        },
        {
          rule_name: 'link',
          description: 'link to ${out}',
          command: 'llvm-link -o ${out} ${in} ${link_flags}'
        },
        {
          rule_name: 'extract_symbol_arrays',
          description: 'Extract symbol names from `externals` file (one symbol per one line)',
          command: "ruby -ryaml -e 'puts (ARGV.map{|file| YAML.load_file(file).values_at(*%w|${keys}|)}.flatten + %w|${extra}|).to_s' ${in} > ${out}"
        },
        {
          rule_name: 'compose',
          description: 'generate executables: ${out}',
          command: 'EMCC_DEBUG=1 EMCC_DEBUG_SAVE=1 a2o ${options} -o ${js_path} ${linked_objects}'
        },
        {
          rule_name: 'generate_products',
          description: 'generate products',
          command: 'cp -a ${pre_products_dir}/ ${products_dir} && '\
                   'cp ${shell_html_path} ${products_application_dir} && '\
                   'cp ${service_worker_js_path} ${products_application_dir}'
        },
        {
          rule_name: 'archive',
          description: 'make static link library',
          command: 'rm -f ${out}; llvm-ar rcs ${out} ${objects}'
        },
        {
          rule_name: 'echo',
          description: 'echo text',
          command: 'echo \'${contents}\' > ${out}'
        }
      ]
    end

    def self.file_link(in_relative_path_from_out_path, out_path)
      {
        builds: [{
          outputs: [out_path],
          rule_name: 'ln_sf',
          inputs: [],
          build_variables: {
            'source' => in_relative_path_from_out_path
          }
        }],
        outputs: [out_path]
      }
    end

    def self.file_copy(in_path, out_dir, in_prefix_path)
      in_path = Pathname(in_path) unless in_path.instance_of?(Pathname)
      in_prefix_path = Pathname(in_prefix_path) unless in_prefix_path.instance_of?(Pathname)
      rel_path = in_path.relative_path_from(in_prefix_path)

      output_path = File.join(out_dir, rel_path.to_s)

      {
        build: {
          outputs: [output_path],
          rule_name: 'cp_r',
          inputs: [in_path.to_s]
        },
        output: output_path
      }
    end

    def self.file_recursive_exec(in_path, out_dir, in_prefix_dir, &block)
      builds = []
      outputs = []

      in_prefix_path = Pathname(in_prefix_dir)
      if File.directory?(in_path)
        Pathname(in_path).find do |path|
          next unless path.file?
          e = file_recursive_exec(path, out_dir, in_prefix_path, &block)
          builds += e[:builds]
          outputs += e[:outputs]
        end
      else
        e = yield(in_path, out_dir, in_prefix_path)
        builds << e[:build]
        outputs << e[:output]
      end

      {
        builds: builds,
        outputs: outputs
      }
    end

    def self.file_recursive_copy(in_path, out_dir, in_prefix_dir = '.')
      file_recursive_exec(in_path, out_dir, in_prefix_dir) do |in_path2, out_dir2, in_prefix_dir2|
        file_copy(in_path2, out_dir2, in_prefix_dir2)
      end
    end
  end
end
