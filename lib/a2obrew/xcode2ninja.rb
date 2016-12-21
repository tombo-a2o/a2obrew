require 'set'
require 'json'
require 'xcodeproj'
require 'fileutils'
require 'pathname'
require 'rexml/document' # For parsing storyboard

require_relative 'util'

# rubocop:disable Metrics/ParameterLists

class Object
  def ninja_escape
    to_s.gsub(/ /, '$ ')
  end
end

module A2OBrew
  class Xcode2Ninja # rubocop:disable Metrics/ClassLength
    APPLE_APPICONS = [
      [60, 3], # 60x60@3x 180x180 (main icon for iPhone retina iOS 8-)
      [76, 2], # 76x76@2x 152x152 (main icon for iPad   retina iOS 7-)
      [72, 2], # 72x72@2x 144x144 (main icon for iPad   retina iOS 6)
      [60, 2], # 60x60@2x 120x120 (main icon for iPhone retina iOS 7)
      [57, 2], # 57x57@2x 114x114 (main icon for iPhone retina iOS 6)
      [76, 1], # 76x76            (main icon for iPad          iOS 7-)
      [72, 1], # 72x72            (main icon for iPad          iOS 6)
      [57, 1], # 57x57            (main icon for iPhone        iOS 6)
    ].freeze

    def initialize(xcodeproj_path)
      self.xcodeproj_path = xcodeproj_path
      @frameworks = []
      @static_libraries = []
    end

    def xcode2ninja(output_dir, # rubocop:disable Metrics/MethodLength
                    xcodeproj_target = nil, build_config_name = nil,
                    active_project_config = {}, a2o_target = nil)
      raise Informative, 'Please specify Xcode project.' unless @xcodeproj_path

      gen_paths = []

      xcodeproj.targets.each do |target|
        next if xcodeproj_target && target.name != xcodeproj_target
        target.build_configurations.each do |build_config|
          next if build_config_name && build_config.name != build_config_name
          gen_path = generate_ninja_build(
            output_dir,
            xcodeproj, target, build_config,
            active_project_config, a2o_target
          )
          gen_paths << gen_path
        end
      end

      gen_paths
    end

    private

    def xcodeproj_path
      raise Informative, 'Please specify Xcode project.' unless @xcodeproj_path
      @xcodeproj_path
    end

    def xcodeproj_dir
      raise Informative, 'Please specify Xcode project.' unless @xcodeproj_dir
      @xcodeproj_dir
    end

    def xcodeproj_path=(path)
      @xcodeproj_path = path && Pathname.new(path).expand_path
      @xcodeproj_dir = File.dirname(@xcodeproj_path)
    end

    def xcodeproj
      @xcodeproj ||= Xcodeproj::Project.open(xcodeproj_path)
    end

    def generate_ninja_build(output_dir, xcodeproj, target, build_config, active_project_config, a2o_target)
      builds = generate_build_statements(xcodeproj, target, build_config, active_project_config, a2o_target)
      rules = generate_rules
      write_ninja_build(output_dir, target, build_config, a2o_target, builds, rules)
    end

    def generate_build_statements(xcodeproj, target, build_config, active_project_config, a2o_target) # rubocop:disable Metrics/MethodLength,Metrics/LineLength,Metrics/AbcSize,Metrics/CyclomaticComplexity
      builds = []
      target.build_phases.each do |phase|
        builds += case phase
                  when Xcodeproj::Project::Object::PBXResourcesBuildPhase
                    resources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  when Xcodeproj::Project::Object::PBXSourcesBuildPhase
                    sources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  when Xcodeproj::Project::Object::PBXFrameworksBuildPhase
                    frameworks_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  when Xcodeproj::Project::Object::PBXShellScriptBuildPhase
                    shell_script_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  when Xcodeproj::Project::Object::PBXHeadersBuildPhase
                    header_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  when Xcodeproj::Project::Object::PBXCopyFilesBuildPhase
                    copy_files_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
                  else
                    raise Informative, "Don't support the phase #{phase.class.name}."
                  end
      end

      if target.isa == 'PBXNativeTarget'
        builds += case target.product_type
                  when 'com.apple.product-type.library.static'
                    static_library_build_phase(xcodeproj, target, build_config, nil, active_project_config, a2o_target)
                  when 'com.apple.product-type.application'
                    application_build_phase(xcodeproj, target, build_config, nil, active_project_config, a2o_target)
                  else
                    raise Informative, "Don't support productType #{target.product_type}."
                  end
      end

      builds += after_build_phase(xcodeproj, target, build_config, nil, active_project_config, a2o_target)

      target.dependencies.each do |dependency|
        proxy = dependency.target_proxy
        if proxy.remote?
          remote_object_file = xcodeproj.objects_by_uuid[proxy.container_portal]
          remote_project_path = File.dirname(remote_object_file.path)
          remote_target = proxy.proxied_object
          remote_product = remote_target.product_reference
          remote_lib_path = File.join(remote_project_path, pre_products_dir(a2o_target), remote_product.path)
          builds << {
            outputs: [remote_lib_path],
            rule_name: 'xcodebuild',
            inputs: [remote_project_path],
            build_variables: {
              a2o_target: a2o_target,
              xcodeproj_target: remote_target.name.ninja_escape
            }
          }
        else
          builds += generate_build_statements(xcodeproj, dependency.target,
                                              build_config, active_project_config, a2o_target)
        end
      end

      builds
    end

    def write_ninja_build(output_dir, _target, _build_config, a2o_target, builds, rules) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/LineLength
      Util.mkdir_p(output_dir)

      path = File.join(output_dir, "#{a2o_target}.ninja.build")
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
          inputs = b[:inputs].map(&:ninja_escape).join(' ')
          outputs = b[:outputs].map(&:ninja_escape).join(' ')
          f.puts "build #{outputs}: #{b[:rule_name]} #{inputs}"

          # build_variables should be escaped at caller
          build_variables = b[:build_variables] || []
          build_variables.each do |k, v|
            f.puts "  #{k} = #{v}"
          end
          f.puts ''
        end
      end

      path
    end

    def generate_rules # rubocop:disable Metrics/MethodLength
      [
        {
          rule_name: 'cp_r',
          description: 'cp -r from ${in} to ${out}',
          command: 'cp -r ${in} ${out}'
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
          command: 'ibtool --errors --warnings --notices --module ${module_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --compilation-directory `dirname ${temp_dir}` ${in} && ibtool --errors --warnings --notices --module ${module_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --link ${resources_dir} ${temp_dir}' # rubocop:disable LineLength
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
          command: "python #{emscripten_dir}/tools/file_packager.py ${target} --lz4 --preload ${packager_target_dir}@/ --js-output=${js_output} --no-heap-copy ${options} --use-preload-plugins" # rubocop:disable LineLength
        },
        # NOTE: A2O_LIBBSD_HEADERS indicates <stdlib.h> loads <bsd/stdlib.h> too.
        {
          rule_name: 'cc',
          description: 'compile ${source} to ${out}',
          deps: 'gcc',
          depfile: '${out}.d',
          command: 'a2o -MMD -MF ${out}.d -Wno-absolute-value ${cc_flags} ${file_cflags} -DA2O_LIBBSD_HEADERS -c ${source} -o ${out}' # rubocop:disable LineLength
        },
        {
          rule_name: 'link',
          description: 'link to ${out}',
          command: 'llvm-link -o ${out} ${in} ${link_flags}'
        },
        {
          rule_name: 'shared_library_js',
          description: 'List of shared libraries to be linked',
          command: 'echo "Module.dynamicLibraries = [${shared_libraries}];" > ${out}'
        },
        {
          rule_name: 'exports_js',
          description: 'Functions to be exported in main module, which are referenced from shared libraries',
          command: %q!llvm-nm -print-file-name -just-symbol-name -undefined-only ${in} | ruby -e "puts (ARGF.map{|l| '_'+l.strip.split(': ',2)[1]}+['_main']).to_s" > ${out}! # rubocop:disable LineLength
        },
        {
          rule_name: 'library_functions_js',
          description: 'Functions defined in side module',
          command: %q!llvm-nm -print-file-name -defined-only ${in} | ruby -e "puts (ARGF.map{ |l| l.strip.split(': ',2)[1][9..-1].split(' ',2)}.select{ |t,s| s if 'DTS'.include?(t) }.map{|t,s| '_'+s}).to_s" > ${out}! # rubocop:disable LineLength
          # input:
          # build/debug/Foundation.bc: -------- T predicate_set_out
          # <---    filename      -->  <--??--> ^ <---- symbol ----
          #                                   type
          # output:
          # select '_'+name where type == "T" or "D" or "S"
        },
        {
          rule_name: 'html',
          description: 'generate executables: ${out}',
          command: 'EMCC_DEBUG=1 EMCC_DEBUG_SAVE=1 a2o -v ${framework_options} ${lib_options} ${separate_asm_options} ${shell_file_options} -s VERBOSE=1 -s LZ4=1 -s NATIVE_LIBDISPATCH=1 -o ${html_path} ${linked_objects} --pre-js ${data_js} ${shared_library_options} -licuuc -licui18n -licudata --memory-init-file 1 ${html_flags}' # rubocop:disable LineLength
        },
        {
          rule_name: 'generate_products',
          description: 'generate products',
          command: 'cp -a ${pre_products_dir}/ ${products_dir}'
        },
        {
          rule_name: 'archive',
          description: 'make static link library',
          command: 'rm -f ${out}; llvm-ar rcs ${out} ${in}'
        }
      ]
    end

    # paths

    def build_dir(a2o_target)
      "a2o/build/#{a2o_target}"
    end

    # paths for file packager

    def packager_target_dir(a2o_target)
      "#{build_dir(a2o_target)}/files"
    end

    def bundle_dir(a2o_target)
      "#{packager_target_dir(a2o_target)}/Contents"
    end

    def framework_bundle_dir(a2o_target)
      "#{packager_target_dir(a2o_target)}/frameworks"
    end

    def resources_dir(a2o_target)
      "#{bundle_dir(a2o_target)}/Resources"
    end

    def tombo_icon_dir(a2o_target)
      "#{pre_products_tombo_dir(a2o_target)}/icon"
    end

    def objects_dir(a2o_target)
      "#{build_dir(a2o_target)}/objects"
    end

    # pre_products' paths to be coped to products

    def pre_products_dir(a2o_target)
      "#{build_dir(a2o_target)}/pre_products"
    end

    def pre_products_application_dir(a2o_target)
      "#{pre_products_dir(a2o_target)}/application"
    end

    def pre_products_tombo_dir(a2o_target)
      "#{pre_products_dir(a2o_target)}/tombo"
    end

    def pre_products_path_prefix(a2o_target)
      "#{pre_products_application_dir(a2o_target)}/application"
    end

    def data_path(a2o_target)
      "#{pre_products_path_prefix(a2o_target)}.dat"
    end

    def js_path(a2o_target)
      "#{pre_products_path_prefix(a2o_target)}.js"
    end

    def asm_js_path(a2o_target)
      "#{pre_products_path_prefix(a2o_target)}.asm.js"
    end

    def html_path(a2o_target)
      "#{pre_products_path_prefix(a2o_target)}.html"
    end

    def html_mem_path(a2o_target)
      "#{html_path(a2o_target)}.mem"
    end

    # products dir is packaged

    def products_dir(a2o_target)
      "#{build_dir(a2o_target)}/products"
    end

    # emscripten paths

    def emscripten_dir
      ENV['EMSCRIPTEN']
    end

    def frameworks_dir
      "#{emscripten_dir}/system/frameworks"
    end

    # emscripten work paths

    def emscripten_work_dir(a2o_target)
      "#{build_dir(a2o_target)}/emscripten"
    end

    def bitcode_path(a2o_target, target)
      "#{emscripten_work_dir(a2o_target)}/application.#{target.name.tr(' ', '_')}.bc"
    end

    def data_js_path(a2o_target)
      "#{emscripten_work_dir(a2o_target)}/data.js"
    end

    def data_js_metadata_path(a2o_target)
      "#{data_js_path(a2o_target)}.metadata"
    end

    def shared_library_js_path(a2o_target)
      "#{emscripten_work_dir(a2o_target)}/shared.js"
    end

    def exports_js_path(a2o_target)
      "#{emscripten_work_dir(a2o_target)}/exports.js"
    end

    def library_functions_js_path(a2o_target)
      "#{emscripten_work_dir(a2o_target)}/lib_funcs.js"
    end

    def a2o_project_flags(active_project_config, rule)
      # TODO: Use Ruby 2.3 and Hash#dig
      flags = active_project_config[:flags]
      flags[rule] if flags
    end

    # phases

    def resources_build_phase(_xcodeproj, target, build_config, phase, active_project_config, a2o_target) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/LineLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      # FIXME: reduce Metrics/AbcSize,Metrics/MethodLength
      builds = []
      resources = []

      resource_filter = active_project_config[:resource_filter]

      icon_asset_catalog = nil
      icon2x = nil
      icon = nil
      phase.files_references.each do |files_ref|
        case files_ref
        when Xcodeproj::Project::Object::PBXFileReference
          files = [files_ref]
        when Xcodeproj::Project::Object::PBXVariantGroup
          files = files_ref.files
        else
          raise Informative, "Don't support the file #{files_ref.class.name}."
        end

        files.each do |file|
          local_path = file.real_path.relative_path_from(Pathname(xcodeproj_dir))

          next if resource_filter && !resource_filter.call(local_path.to_s)

          if File.extname(file.path) == '.storyboard'
            remote_path = File.join(resources_dir(a2o_target), file.path)
            remote_path += 'c'
            tmp_path = File.join('tmp', remote_path)

            nps = get_nib_paths_from_storyboard(local_path)
            nps << 'Info.plist'
            nib_paths = nps.map { |np| File.join(remote_path, np) }

            builds << {
              outputs: nib_paths,
              rule_name: 'ibtool',
              inputs: [local_path],
              build_variables: {
                'temp_dir' => tmp_path,
                'module_name' => target.product_name,
                'resources_dir' => resources_dir(a2o_target)
              }
            }
            resources += nib_paths
          elsif %w(.caf .aiff).include? File.extname(file.path)
            # convert caf file to mp4, but leave file name as is
            remote_path = File.join(resources_dir(a2o_target), local_path.basename)

            builds << {
              outputs: [remote_path],
              rule_name: 'audio-convert',
              inputs: [local_path]
            }
            resources << remote_path
          else
            if file.path == 'Images.xcassets' || file.path == 'Assets.xcassets'
              # Asset Catalog for icon
              icon_asset_catalog = asset_catalog(local_path, build_config)
            elsif file.path == 'Icon@2x.png'
              # old
              icon2x = [local_path, 2]
            elsif file.path == 'Icon.png'
              # ancient
              icon = [local_path, 1]
            end

            in_prefix = files_ref.class == Xcodeproj::Project::Object::PBXFileReference ? File.dirname(local_path) : '.'

            # All resource files are stored in the same directory
            f = file_recursive_copy(local_path, resources_dir(a2o_target), in_prefix)
            builds += f[:builds]
            resources += f[:outputs]
          end
        end
      end

      infoplist_path = build_setting(build_config, 'INFOPLIST_FILE')
      if infoplist_path
        infoplist = File.join(bundle_dir(a2o_target), 'Info.plist')
        resources << infoplist

        # NOTE: Should we use file_recursive_copy here?
        builds << {
          outputs: [infoplist],
          rule_name: 'cp_r',
          inputs: [infoplist_path]
        }
      end

      # Application Icon
      app_icon = icon_asset_catalog || icon2x || icon
      if app_icon
        icon_output_path = "#{tombo_icon_dir(a2o_target)}/icon-60.png"

        builds << {
          outputs: [icon_output_path],
          rule_name: 'image-convert',
          inputs: [app_icon[0]],
          build_variables: {
            'width' => 60 * app_icon[1],
            'height' => 60 * app_icon[1]
          }
        }
      end

      # Framework resources
      framework_resources = system_framework_resources(a2o_target)
      builds += framework_resources[:builds]
      resources += framework_resources[:outputs]

      # ICU data
      icu_data_in = "#{emscripten_dir}/system/local/share/icu/54.1/icudt54l.dat"
      icu_data_out = "#{packager_target_dir(a2o_target)}/System/icu/icu.dat"
      builds << {
        outputs: [icu_data_out],
        rule_name: 'cp_r',
        inputs: [icu_data_in]
      }
      resources << icu_data_out

      # file_packager
      #
      # NOTE: Could we use --use-preload-cache ?

      t = data_path(a2o_target)
      j = data_js_path(a2o_target)
      data_outputs = [t, j]
      options = ''
      # FIXME: --separate-metadata is not tested and supported
      if A2OCONF[:xcodebuild][:emscripten][:file_packager][:separate_metadata]
        data_outputs << data_js_metadata_path(a2o_target)
        options += ' --separate-metadata'
      end

      builds << {
        outputs: data_outputs,
        rule_name: 'file_packager',
        inputs: resources,
        build_variables: {
          'target' => t,
          'js_output' => j,
          'options' => options,
          'packager_target_dir' => packager_target_dir(a2o_target)
        }
      }

      builds
    end

    def find_icon_from_asset_catalog(base_path)
      contents_images = JSON.parse(File.read(File.join(base_path, 'Contents.json')))['images']

      APPLE_APPICONS.each do |width, scale|
        scale_str = "#{scale}x"
        size_str = "#{width}x#{width}"
        contents_images.each do |ci|
          if ci['scale'] == scale_str && ci['size'] == size_str && ci.key?('filename')
            return File.join(base_path, ci['filename']), scale
          end
        end
      end

      nil
    end

    def asset_catalog(local_path, build_config)
      appicon_name = build_setting(build_config, 'ASSETCATALOG_COMPILER_APPICON_NAME') + '.appiconset'
      # _launchimage_name = build_setting(build_config, 'ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME') + '.launchimage'

      Dir.new(local_path).each do |asset_local_path|
        if asset_local_path == appicon_name
          base_path = File.join(local_path, asset_local_path)
          return find_icon_from_asset_catalog(base_path)
        end
      end

      nil
    end

    def file_copy(in_path, out_dir, in_prefix_path)
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

    def file_recursive_copy(in_path, out_dir, in_prefix_dir = '.') # rubocop:disable Metrics/MethodLength
      builds = []
      outputs = []

      in_prefix_path = Pathname(in_prefix_dir)
      if File.directory?(in_path)
        Pathname(in_path).find do |path|
          next unless path.file?
          e = file_copy(path, out_dir, in_prefix_path)
          builds << e[:build]
          outputs << e[:output]
        end
      else
        e = file_copy(in_path, out_dir, in_prefix_path)
        builds << e[:build]
        outputs << e[:output]
      end

      {
        builds: builds,
        outputs: outputs
      }
    end

    # rubocop:disable Metrics/LineLength
    def sources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      # FIXME: reduce Metrics/AbcSize,Metrics/MethodLength
      builds = []
      objects = []

      header_dirs = xcodeproj.main_group.recursive_children.select { |g| g.path && File.extname(g.path) == '.h' }.map do |g|
        full_path = g.real_path.relative_path_from(Pathname(xcodeproj_dir)).to_s
        File.dirname(full_path)
      end.to_a.uniq

      # build settings
      lib_dirs = build_setting(build_config, 'LIBRARY_SEARCH_PATHS', :array)
      framework_search_paths = build_setting(build_config, 'FRAMEWORK_SEARCH_PATHS', :array)
      header_search_paths = build_setting(build_config, 'HEADER_SEARCH_PATHS', :array).select { |value| value != '' }
      user_header_search_paths = build_setting(build_config, 'USER_HEADER_SEARCH_PATHS', :string) || ''
      other_cflags = (build_setting(build_config, 'OTHER_CFLAGS', :array) || []).join(' ')
      cxx_std = build_setting(build_config, 'CLANG_CXX_LANGUAGE_STANDARD', :string)
      c_std = build_setting(build_config, 'GCC_C_LANGUAGE_STANDARD', :string)
      preprocessor_definitions = (build_setting(build_config, 'GCC_PREPROCESSOR_DEFINITIONS', :array) || []).map { |var| "-D#{var}" }.join(' ')

      lib_options = lib_dirs.map { |dir| "-L#{dir}" }.join(' ')
      framework_dir_options = framework_search_paths.map { |f| "-F#{f}" }.join(' ')
      header_options = (header_search_paths + user_header_search_paths.split + header_dirs).map { |dir| "-I#{dir}" }.join(' ')

      if build_setting(build_config, 'GCC_PRECOMPILE_PREFIX_HEADER', :bool)
        prefix_pch = build_setting(build_config, 'GCC_PREFIX_HEADER')
        prefix_pch_options = prefix_pch.empty? ? '' : "-include #{prefix_pch}"
      end

      # build sources

      cc_flags = [framework_dir_options, header_options, lib_options, prefix_pch_options, other_cflags, preprocessor_definitions, a2o_project_flags(active_project_config, :cc)].join(' ')

      enable_objc_arc = build_setting(build_config, 'CLANG_ENABLE_OBJC_ARC', :bool) # default NO

      phase.files_references.each do |file|
        if file.parent.isa != 'PBXGroup'
          puts '[WARN] Orphan file: ' + file.name
          next
        end
        source_path = file.real_path.relative_path_from(Pathname(xcodeproj_dir))
        basename = source_path.basename('.*').to_s
        uid = Digest::SHA1.new.update(source_path.to_s).to_s[0, 7]
        object = File.join(objects_dir(a2o_target), basename + '-' + uid + '.o')

        settings = file.build_files[0].settings
        file_cflags = []
        if settings && settings.key?('COMPILER_FLAGS')
          file_cflags += settings['COMPILER_FLAGS'].split
        end
        if enable_objc_arc
          file_cflags << '-fobjc-arc' unless file_cflags.include?('-fno-objc-arc')
        end

        case file.last_known_file_type
        when 'sourcecode.cpp.cpp', 'sourcecode.cpp.objcpp'
          file_cflags << "-std=#{cxx_std}" if cxx_std
        when 'sourcecode.c.c', 'sourcecode.c.objc'
          file_cflags << "-std=#{c_std}" if c_std
        when 'sourcecode.c.h'
          # ignore header file
          next
        else
          raise Informative, "Unsupported file type #{file} #{file.last_known_file_type}"
        end

        objects << object

        builds << {
          outputs: [object],
          rule_name: 'cc',
          inputs: [source_path],
          build_variables: {
            'file_cflags' => file_cflags.join(' '),
            'source' => source_path,
            'cc_flags' => cc_flags
          }
        }
      end

      # stubs
      # FIXME: remove
      Dir.glob('*_dummy.*').each do |source_path|
        object = File.join(objects_dir(a2o_target), source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))
        objects << object

        file_cflags = '-fobjc-arc '

        case File.extname(source_path)
        when '.mm', '.cpp', '.cxx', '.cc'
          file_cflags << "-std=#{cxx_std}" if cxx_std
        when '.m', '.c'
          file_cflags << "-std=#{c_std}" if c_std
        else
          raise Informative, "Unsupported file type #{source_path}"
        end

        builds << {
          outputs: [object],
          rule_name: 'cc',
          inputs: [source_path, prefix_pch],
          build_variables: {
            'file_cflags' => file_cflags,
            'source' => source_path,
            'cc_flags' => cc_flags
          }
        }
      end

      # link
      conf_link_flags = a2o_project_flags(active_project_config, :link)

      builds << {
        outputs: [bitcode_path(a2o_target, target)],
        rule_name: 'link',
        inputs: objects,
        build_variables: {
          'link_flags' => conf_link_flags
        }
      }

      builds
    end

    def application_build_phase(_xcodeproj, target, _build_config, _phase, active_project_config, a2o_target) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      builds = []

      # dynamic link libraries

      shared_libraries = A2OCONF[:xcodebuild][:dynamic_link_frameworks]

      builds << {
        outputs: [shared_library_js_path(a2o_target)],
        rule_name: 'shared_library_js',
        inputs: shared_libraries.map { |f| "#{frameworks_dir}/#{f}.framework/#{f}.so.js" },
        build_variables: {
          'shared_libraries' => shared_libraries.map { |f| "'#{f}.so.js'" }.join(',')
        }
      }

      shared_libraries_outputs = []
      shared_libraries.each do |f|
        source = "#{frameworks_dir}/#{f}.framework/#{f}.so.js"
        dest = "#{pre_products_application_dir(a2o_target)}/#{f}.so.js"
        builds << {
          outputs: [dest],
          rule_name: 'cp_r',
          inputs: [source]
        }
        shared_libraries_outputs << dest
      end

      builds << {
        outputs: [exports_js_path(a2o_target)],
        rule_name: 'exports_js',
        inputs: shared_libraries.map { |f| "#{frameworks_dir}/#{f}.framework/#{f}.a" }
      }

      builds << {
        outputs: [library_functions_js_path(a2o_target)],
        rule_name: 'library_functions_js',
        inputs: shared_libraries.map { |f| "#{frameworks_dir}/#{f}.framework/#{f}.a" }
      }

      # executable

      # detect emscripten file changes
      dep_paths = file_list("#{emscripten_dir}/src/")
      A2OCONF[:xcodebuild][:static_link_frameworks].each do |f|
        dep_paths.concat(file_list("#{frameworks_dir}/#{f}.framework/#{f}"))
      end

      # generate html
      conf_html_flags = a2o_project_flags(active_project_config, :html)

      pre_products_outputs = [html_path(a2o_target), html_mem_path(a2o_target), js_path(a2o_target)]

      if A2OCONF[:xcodebuild][:emscripten][:emcc][:separate_asm]
        pre_products_outputs << asm_js_path(a2o_target)
        separate_asm_options = '--separate-asm'
      end

      emscripten_shell_path = active_project_config[:emscripten_shell_path]
      if emscripten_shell_path
        shell_file_options = "--shell-file #{emscripten_shell_path}"
        dep_paths << emscripten_shell_path
      else
        shell_file_options = ''
      end

      linked_objects = @static_libraries + [bitcode_path(a2o_target, target)]
      static_link_frameworks = Set.new(@frameworks) + A2OCONF[:xcodebuild][:static_link_frameworks] - shared_libraries

      builds << {
        outputs: pre_products_outputs,
        rule_name: 'html',
        inputs: [data_js_path(a2o_target), shared_library_js_path(a2o_target), exports_js_path(a2o_target), library_functions_js_path(a2o_target)] + linked_objects + dep_paths,
        build_variables: {
          'data_js' => data_js_path(a2o_target),
          'shared_library_options' => shared_libraries.empty? ? '' : "-s MAIN_MODULE=2 -s LINKABLE=0 -s EXPORTED_FUNCTIONS=@#{exports_js_path(a2o_target)} -s LIBRARY_IMPLEMENTED_FUNCTIONS=@#{library_functions_js_path(a2o_target)} --pre-js #{shared_library_js_path(a2o_target)}",
          'linked_objects' => linked_objects.map { |o| '"' + o.ninja_escape + '"' }.join(' '),
          'framework_options' => static_link_frameworks.map { |f| "-framework #{f.ninja_escape}" }.join(' '),
          'lib_options' => `PKG_CONFIG_LIBDIR=#{emscripten_dir}/system/lib/pkgconfig:#{emscripten_dir}/system/local/lib/pkgconfig pkg-config freetype2 --libs`.strip + ' -lcrypto',
          'separate_asm_options' => separate_asm_options,
          'shell_file_options' => shell_file_options,
          'html_path' => html_path(a2o_target),
          'html_flags' => conf_html_flags
        }
      }

      # copy pre_products to products

      # TODO: All files except application.html are cached by reverse-proxy or browser.
      #       It may results a problem when releasing a new version.
      #       So we'll change file paths like this.
      #       ```
      #       require 'securerandom'
      #       cp pre_products/application.* products/#{SecureRandom.hex(16)}.* unless application.html
      #       ```
      #       But currently, just copy them as the original.

      products_inputs = pre_products_outputs + shared_libraries_outputs + [data_path(a2o_target)]
      products_outputs = products_inputs.map do |path|
        path.sub('pre_products', 'products')
      end

      builds << {
        outputs: products_outputs,
        rule_name: 'generate_products',
        inputs: products_inputs,
        build_variables: {
          'pre_products_dir' => pre_products_dir(a2o_target),
          'products_dir' => products_dir(a2o_target)
        }
      }

      builds
    end
    # rubocop:enable Metrics/LineLength

    def static_library_build_phase(_xcodeproj, target, _build_config, _phase, _active_project_config, a2o_target)
      builds = []

      library_path = "#{pre_products_dir(a2o_target)}/#{target.product_reference.path}"

      builds << {
        outputs: [library_path],
        rule_name: 'archive',
        inputs: [bitcode_path(a2o_target, target)]
      }

      builds
    end

    def frameworks_build_phase(_xcodeproj, _target, _build_config, phase, _active_project_config, a2o_target) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,LineLength
      builds = []

      @frameworks = []
      @static_libraries = []
      phase.files.each do |file|
        file_ref = file.file_ref
        case file_ref
        when Xcodeproj::Project::Object::PBXFileReference
          # TODO: handle .a and .dylib
          name = file_ref.name
          if name && name.end_with?('.framework')
            @frameworks << File.basename(name, '.framework')
          end
        when Xcodeproj::Project::Object::PBXReferenceProxy
          proxy = file_ref.remote_ref
          remote_object_file = xcodeproj.objects_by_uuid[proxy.container_portal]
          # FIXME: determine remote target more appropriately
          library_path = File.join(File.dirname(remote_object_file.path), pre_products_dir(a2o_target), file_ref.path) # rubocop:disable LineLength
          @static_libraries << library_path
        else
          raise Informative, "Unsupported file_ref #{file_ref}"
        end
      end

      builds
    end

    def header_build_phase(_xcodeproj, _target, _build_config, _phase, _active_project_config, _a2o_target)
      # FIXME: Implement
      []
    end

    def shell_script_build_phase(_xcodeproj, _target, _build_config, _phase, _active_project_config, _a2o_target)
      # FIXME: Implement
      []
    end

    def copy_files_phase(_xcodeproj, _target, _build_config, _phase, _active_project_config, _a2o_target)
      # FIXME: Implement
      []
    end

    def after_build_phase(_xcodeproj, _target, _build_config, _phase, active_project_config, a2o_target)
      builds = []

      # Copying files to distribute_path
      distribute_paths = active_project_config[:distribute_paths]
      if distribute_paths
        out_dir = pre_products_application_dir(a2o_target)

        distribute_paths.each do |distribute_path|
          f = file_recursive_copy(distribute_path, out_dir, distribute_path)
          builds += f[:builds]
          # no need for outputs
        end
      end

      builds
    end

    # utils
    def build_setting(build_config, prop, type = nil) # rubocop:disable Metrics/MethodLength
      # TODO: check xcconfig file
      default_setting = nil # TODO set iOS default
      project_setting = xcodeproj.build_settings(build_config.name)[prop]
      project_setting = project_setting.clone if project_setting
      target_setting = build_config.build_settings[prop]
      target_setting = target_setting.clone if target_setting

      env = {
        'PROJECT_DIR' => xcodeproj_dir,
        'SRCROOT' => xcodeproj_dir,
        'PLATFORM_NAME' => 'emscripten',
        'SDKROOT' => emscripten_dir,
        'DEVELOPER_FRAMEWORKS_DIR' => '', # FIXME: currently ignores
        'MYPROJ_HOME' => '' # FIXME: currently ignores
      }

      if target_setting
        expand(replace_inherited(replace_inherited(target_setting, project_setting), default_setting), env, type)
      elsif project_setting
        expand(replace_inherited(project_setting, default_setting), env, type)
      else
        expand(default_setting, env, type)
      end
    end

    def replace_inherited(lower, upper)
      # replace '$(inherited)'
      if lower.is_a?(Array)
        # Array
        idx = lower.index('$(inherited)')
        lower[idx, 1] = upper || [] if idx
      elsif lower.respond_to?(:gsub!)
        # String
        lower.gsub!(/\$\(inherited\)/, upper || '')
      end

      lower
    end

    def expand(value, env, type = nil) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity
      if value.is_a?(Array)
        value.map do |v|
          expand(v, env)
        end
      else
        case type
        when :bool
          value == 'YES'
        when :array
          if value.nil?
            []
          else
            [expand(value, env)]
          end
        else
          if value.nil?
            nil
          else
            resolve_macro(value, env)
          end
        end
      end
    end

    def resolve_macro(value, env)
      value.gsub(/\$\(([A-Za-z0-9_]+)\)/) do |m|
        varname = Regexp.last_match(1)

        raise Informative, "Not support for #{m}" unless env.key?(varname)

        env[varname]
      end
    end

    def get_nib_paths_from_storyboard(storyboard_path) # rubocop:disable Metrics/AbcSize
      d = REXML::Document.new(File.read(storyboard_path))

      nib_list = []

      d.elements.each('//*[@storyboardIdentifier]') do |e|
        nib_list << e.attribute('storyboardIdentifier').to_s
        next unless e.name.intern == :viewController
        prefix = e.attributes['id'].to_s
        e.each_element('view') do |v|
          view_id = v.attributes['id'].to_s
          nib_list << "#{prefix}-view-#{view_id}"
        end
      end

      nib_list.sort.map do |nib_prefix|
        "#{nib_prefix}.nib"
      end
    end

    def system_framework_resources(a2o_target)
      builds = []
      outputs = []
      out_dir = framework_bundle_dir(a2o_target)

      Dir.glob("#{frameworks_dir}/*.framework/Resources/") do |path|
        f = file_recursive_copy(path, out_dir, frameworks_dir)
        builds += f[:builds]
        outputs += f[:outputs]
      end

      { builds: builds, outputs: outputs }
    end

    def file_list(dir)
      files = []
      Pathname(dir).find do |path|
        next unless path.file?
        files << path
      end
      files
    end
  end
end
