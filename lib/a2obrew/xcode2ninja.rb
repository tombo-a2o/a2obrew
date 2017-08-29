# frozen_string_literal: true

require 'set'
require 'json'
require 'xcodeproj'
require 'fileutils'
require 'pathname'
require 'rexml/document' # For parsing storyboard

require_relative 'util'
require_relative 'ninja'
require_relative 'xcodeproj_ext'

# rubocop:disable Metrics/ParameterLists

module A2OBrew
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

  class Xcode2Ninja
    def initialize(xcodeproj_path, xcodeproj_name, a2obrew_path)
      raise Informative, 'Please specify Xcode project.' unless xcodeproj_path

      @xcodeproj_path = Pathname.new(xcodeproj_path).expand_path
      @xcodeproj_name = xcodeproj_name
      @a2obrew_path = a2obrew_path
    end

    def xcode2ninja(output_dir,
                    xcodeproj_target = nil, build_config_name = nil,
                    active_project_config = {}, a2o_target_name = nil)

      builds = []

      default_target = xcworkspace ? xcworkspace.find_target(@xcodeproj_name, xcodeproj_target) : xcodeproj.find_target(xcodeproj_target)
      dependent_targets = default_target.dependent_targets(xcworkspace).to_a

      targets = [default_target] + dependent_targets
      a2o_targets = targets.map do |target|
        A2OTarget.new(target, build_config_name, active_project_config, a2o_target_name, @a2obrew_path, File.dirname(@xcodeproj_path))
      end

      a2o_targets.each do |a2o_target|
        builds += a2o_target.generate_build_statements
      end

      [Ninja.write_ninja_build(output_dir, a2o_target_name, builds, [a2o_targets[0].phony_target_name])]
    end

    private

    def xcworkspace
      @workspace ||= File.extname(@xcodeproj_path) == '.xcworkspace' ? Xcodeproj::Workspace.new_from_xcworkspace(@xcodeproj_path) : nil
    end

    def xcodeproj
      @xcodeproj ||= File.extname(@xcodeproj_path) != '.xcworkspace' ? Xcodeproj::Project.open(@xcodeproj_path) : nil
    end
  end

  class A2OTarget
    def initialize(target, build_config_name, active_project_config, a2o_target_name, a2obrew_path, base_dir)
      @target = target
      @build_config = target.build_configurations.find { |build_config| build_config.name == build_config_name }
      @active_project_config = active_project_config
      @a2o_target_name = a2o_target_name
      @a2obrew_path = a2obrew_path
      @base_dir = base_dir
    end

    def generate_build_statements
      builds = []
      @target.build_phases.each do |phase|
        builds += case phase
                  when Xcodeproj::Project::Object::PBXResourcesBuildPhase
                    resources_build_phase(phase)
                  when Xcodeproj::Project::Object::PBXSourcesBuildPhase
                    sources_build_phase(phase)
                  when Xcodeproj::Project::Object::PBXFrameworksBuildPhase
                    frameworks_build_phase(phase)
                  when Xcodeproj::Project::Object::PBXShellScriptBuildPhase
                    shell_script_build_phase(phase)
                  when Xcodeproj::Project::Object::PBXHeadersBuildPhase
                    header_build_phase(phase)
                  when Xcodeproj::Project::Object::PBXCopyFilesBuildPhase
                    copy_files_phase(phase)
                  else
                    raise Informative, "Don't support the phase #{phase.class.name}."
                  end
      end

      builds += generate_target_specific_build_statements

      builds += after_build_phase

      builds
    end

    def generate_target_specific_build_statements
      builds = []

      if @target.isa == 'PBXNativeTarget'
        builds += case @target.product_type
                  when 'com.apple.product-type.library.static'
                    static_library_build_phase
                  when 'com.apple.product-type.application'
                    application_build_phase
                  when 'com.apple.product-type.bundle.unit-test'
                    unit_test_build_phase
                  else
                    raise Informative, "Don't support productType #{@target.product_type}."
                  end
      elsif @target.isa == 'PBXAggregateTarget'
        # TODO: implement this
        builds << {
          outputs: [phony_target_name],
          rule_name: 'phony',
          inputs: dependent_target_names
        }
      end

      builds
    end

    # paths

    def xcodeproj_dir
      File.dirname(@target.project.path)
    end

    def build_dir
      "a2o/build/#{@a2o_target_name}"
    end

    # paths for file packager

    def packager_target_dir
      "#{build_dir}/files"
    end

    def bundle_dir
      "#{packager_target_dir}/a2o_application.app"
    end

    def framework_bundle_dir
      "#{packager_target_dir}/frameworks"
    end

    def resources_dir
      bundle_dir
    end

    def application_icon_dir
      "#{pre_products_application_dir}/icon"
    end

    def application_launch_image_dir
      "#{pre_products_application_dir}/launch-image"
    end

    def tombo_icon_dir
      "#{pre_products_tombo_dir}/icon"
    end

    def tombo_ogp_dir
      "#{pre_products_tombo_dir}/ogp"
    end

    def objects_dir
      "#{build_dir}/#{@target.unique_name}/objects"
    end

    # pre_products' paths to be coped to products

    def pre_products_dir
      "#{build_dir}/#{@target.unique_name}/pre_products"
    end

    def pre_products_application_dir
      "#{pre_products_dir}/application"
    end

    def pre_products_tombo_dir
      "#{pre_products_dir}/tombo"
    end

    def pre_products_path_prefix
      "#{pre_products_application_dir}/application"
    end

    def data_path
      "#{pre_products_path_prefix}.dat"
    end

    def js_path
      "#{pre_products_path_prefix}.js"
    end

    def asm_js_path
      "#{pre_products_path_prefix}.asm.js"
    end

    def wasm_js_path
      "#{pre_products_path_prefix}-wasm.js"
    end

    def wasm_asm_js_path
      "#{pre_products_path_prefix}-wasm.asm.js"
    end

    def wasm_path
      "#{pre_products_path_prefix}-wasm.wasm"
    end

    def html_path
      "#{pre_products_path_prefix}.html"
    end

    def js_mem_path
      "#{js_path}.mem"
    end

    def js_symbols_path
      "#{js_path}.symbols"
    end

    def wasm_js_symbols_path
      "#{wasm_js_path}.symbols"
    end

    def platform_parameters_json_path
      "#{pre_products_tombo_dir}/parameters.json"
    end

    def runtime_parameters_json_path
      "#{pre_products_application_dir}/runtime_parameters.json"
    end

    def application_icon_output_path
      "#{application_icon_dir}/icon-60.png"
    end

    def application_launch_image_output_path
      "#{application_launch_image_dir}/launch-image-320x480.png"
    end

    def tombo_icon_output_path
      "#{tombo_icon_dir}/icon-60.png"
    end

    def tombo_ogp_image_output_path(lang)
      "#{tombo_ogp_dir}/#{lang}.png"
    end

    # products dir is packaged

    def products_dir
      "#{build_dir}/products"
    end

    def products_application_dir
      "#{products_dir}/application"
    end

    def products_html_path
      "#{products_application_dir}/application.html"
    end

    def products_service_worker_js_path
      "#{products_application_dir}/service_worker.js"
    end

    def products_shell_files_link_dir
      "#{products_application_dir}/shell_files"
    end

    # unit test

    def unit_test_dir
      "#{build_dir}/unit_test"
    end

    def unit_test_application_dir
      "#{unit_test_dir}/application"
    end

    def unit_test_html_path
      "#{unit_test_application_dir}/application.html"
    end

    def unit_test_service_worker_js_path
      "#{unit_test_application_dir}/service_worker.js"
    end

    def unit_test_shell_files_link_dir
      "#{unit_test_application_dir}/shell_files"
    end

    # a2obrew paths

    def a2obrew_dir
      @a2obrew_path
    end

    def shell_template_dir
      "#{a2obrew_dir}/shell"
    end

    def shell_files_source_dir
      "#{shell_template_dir}/shell_files"
    end

    def application_template_html_path
      "#{shell_template_dir}/application.html"
    end

    def service_worker_template_js_path
      "#{shell_template_dir}/service_worker.js"
    end

    # emscripten paths

    def emscripten_dir
      ENV['EMSCRIPTEN']
    end

    def frameworks_dir
      "#{emscripten_dir}/system/frameworks"
    end

    # emscripten work paths

    def emscripten_work_dir
      "#{build_dir}/emscripten"
    end

    def bitcode_path
      "#{emscripten_work_dir}/application.#{@target.name.tr(' ', '_')}.bc"
    end

    def data_js_path
      "#{emscripten_work_dir}/data.js"
    end

    def data_js_metadata_path
      "#{data_js_path}.metadata"
    end

    def shared_library_js_path(extension)
      "#{emscripten_work_dir}/shared.#{extension}.js"
    end

    def exported_functions_js_path(extension)
      "#{emscripten_work_dir}/exported_functions.#{extension}.js"
    end

    def exported_variables_js_path(extension)
      "#{emscripten_work_dir}/exported_variables.#{extension}.js"
    end

    def library_functions_js_path(extension)
      "#{emscripten_work_dir}/lib_funcs.#{extension}.js"
    end

    def a2o_project_flags(rule)
      @active_project_config.dig(:flags, rule)
    end

    def phony_target_name
      @target.unique_name
    end

    def dependent_target_names
      @target.dependencies.map do |dependency|
        proxy = dependency.target_proxy
        target = proxy.proxied_object
        target.unique_name
      end
    end

    # phases

    def resources_build_phase(phase) # rubocop:disable Metrics/MethodLength,AbcSize,CyclomaticComplexity,PerceivedComplexity
      builds = []
      resources = []

      resource_filter = @active_project_config[:resource_filter]

      icon_asset_catalog = nil
      icon2x = nil
      icon = nil
      launch_image_asset_catalog = nil
      launch_image2x = nil
      launch_image = nil

      phase.files_references.each do |files_ref| # rubocop:disable Metrics/BlockLength
        case files_ref
        when Xcodeproj::Project::Object::PBXFileReference
          files = [files_ref]
        when Xcodeproj::Project::Object::PBXVariantGroup
          files = files_ref.files
        else
          raise Informative, "Don't support the file #{files_ref.class.name}."
        end

        files.each do |file| # rubocop:disable Metrics/BlockLength
          local_path = file.real_path.relative_path_from(Pathname(@base_dir))

          next if resource_filter && !resource_filter.call(local_path.to_s)

          if File.extname(file.path) == '.storyboard'
            remote_path = File.join(resources_dir, File.basename(file.path))
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
                'module_name' => @target.product_name,
                'resources_dir' => resources_dir
              }
            }
            resources += nib_paths
          elsif File.extname(file.path) == '.xib'
            remote_path = File.join(resources_dir, File.basename(file.path, '.xib') + '.nib')

            builds << {
              outputs: [remote_path],
              rule_name: 'ibtool2',
              inputs: [local_path],
              build_variables: {
                'module_name' => @target.product_name
              }
            }
            resources << remote_path
          else
            if file.path.end_with?('Images.xcassets', 'Assets.xcassets')
              # Asset Catalog for icon and launch images
              icon_asset_catalog, launch_image_asset_catalog = asset_catalog(local_path)
            elsif file.path == 'Icon@2x.png'
              # For an old iPhone application
              icon2x = [local_path, 2]
            elsif file.path == 'Icon.png'
              # For an ancient iPhone application
              icon = [local_path, 1]
            elsif file.path == 'Default@2x.png'
              # For an old iPhone application
              launch_image2x = [local_path, 2]
            elsif file.path == 'Default.png'
              # For an ancient iPhone application
              launch_image = [local_path, 1]
            end

            in_prefix = if files_ref.class == Xcodeproj::Project::Object::PBXFileReference
                          File.dirname(local_path)
                        else
                          File.dirname(File.dirname(local_path)) # don't remove "xxx.lproj"
                        end

            # All resource files are stored in the same directory
            f = Ninja.file_recursive_exec(local_path, resources_dir, in_prefix) do |in_path, out_dir, in_prefix_dir|
              if %w[.caf .aiff].include? File.extname(in_path)
                # convert caf file to mp4, but leave file name as is

                rel_path = in_path.relative_path_from(in_prefix_dir)
                remote_path = File.join(resources_dir, rel_path)
                {
                  build: {
                    outputs: [remote_path],
                    rule_name: 'audio-convert',
                    inputs: [in_path]
                  },
                  output: remote_path
                }
              else
                Ninja.file_copy(in_path, out_dir, in_prefix_dir)
              end
            end
            builds += f[:builds]
            resources += f[:outputs]
          end
        end
      end

      infoplist_path = build_setting('INFOPLIST_FILE')
      if infoplist_path
        infoplist = File.join(bundle_dir, 'Info.plist')
        resources << infoplist

        # TODO: replace all variables
        variables = %w[PRODUCT_NAME PRODUCT_BUNDLE_IDENTIFIER]
        commands = variables.map do |key|
          value = build_setting(key)
          %!-e "s/\\$\\(#{key}\\)/#{value}/g" -e "s/\\${#{key}}/#{value}/g"!
        end.join(' ')

        # NOTE: Should we use file_recursive_copy here?
        builds << {
          outputs: [infoplist],
          rule_name: 'sed',
          inputs: [infoplist_path],
          build_variables: {
            'options' => commands.ninja_escape
          }
        }
      end

      # Application Icon
      app_icon = icon_asset_catalog || icon2x || icon
      if app_icon
        @icon_output_paths = [
          application_icon_output_path,
          tombo_icon_output_path
        ]
        @icon_output_paths.each do |icon_output_path|
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
      end

      # Launch Image
      app_launch_image = launch_image_asset_catalog || launch_image2x || launch_image
      if app_launch_image.nil? && @active_project_config[:launch_image]
        path = @active_project_config[:launch_image]
        width, height = Util.image_width_and_height(path)
        # FIXME: Repair this dirty logic
        ratio = width >= 640 && height >= 960 ? 2 : 1
        app_launch_image = [path, ratio]
      end

      if app_launch_image
        @launch_image_output_path = application_launch_image_output_path
        builds << {
          outputs: [@launch_image_output_path],
          rule_name: 'image-convert',
          inputs: [app_launch_image[0]],
          build_variables: {
            'width' => 320 * app_launch_image[1],
            'height' => 480 * app_launch_image[1]
          }
        }
      end

      # OGP images
      if @active_project_config[:ogp_images]
        @ogp_image_output_paths = []
        @active_project_config[:ogp_images].each do |lang, img_path|
          output_path = tombo_ogp_image_output_path(lang)
          @ogp_image_output_paths << output_path
          builds << {
            outputs: [output_path],
            rule_name: 'cp_r',
            inputs: [img_path]
          }
        end
      end

      # Framework resources
      framework_resources = system_framework_resources
      builds += framework_resources[:builds]
      resources += framework_resources[:outputs]

      # ICU data
      icu_data_in = "#{emscripten_dir}/system/local/share/icu/54.1/icudt54l.dat"
      icu_data_out = "#{packager_target_dir}/System/icu/icu.dat"
      builds << {
        outputs: [icu_data_out],
        rule_name: 'cp_r',
        inputs: [icu_data_in]
      }
      resources << icu_data_out

      # file_packager
      #
      # NOTE: Could we use --use-preload-cache ?

      t = data_path
      j = data_js_path
      data_outputs = [t, j]
      options = ''
      # FIXME: --separate-metadata is not tested and supported
      if A2OCONF[:xcodebuild][:emscripten][:file_packager][:separate_metadata]
        data_outputs << data_js_metadata_path
        options += ' --separate-metadata'
      end

      builds << {
        outputs: data_outputs,
        rule_name: 'file_packager',
        inputs: resources,
        build_variables: {
          'target' => t.quote.ninja_escape,
          'js_output' => j,
          'options' => options,
          'packager_target_dir' => packager_target_dir
        }
      }

      builds
    end

    def find_icon_from_asset_catalog(base_path)
      contents_images = JSON.parse(File.read(
                                     File.join(base_path, 'Contents.json')
      ))['images']

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

    def find_launch_image_from_asset_catalog(base_path)
      contents_images = JSON.parse(File.read(
                                     File.join(base_path, 'Contents.json')
      ))['images']

      [2, 1].each do |scale|
        scale_str = "#{scale}x"
        orientation = 'portrait' # FIXME: we should consider orientation
        idiom = 'iphone'
        subtype = nil

        contents_images.each do |ci|
          if ci['scale'] == scale_str &&
             ci['orientation'] == orientation &&
             ci['idiom'] == idiom &&
             ci['subtype'] == subtype &&
             ci['filename']
            return File.join(base_path, ci['filename']), scale
          end
        end
      end

      nil
    end

    def asset_catalog(local_path)
      appicon_name = build_setting('ASSETCATALOG_COMPILER_APPICON_NAME') + '.appiconset'
      launchimage_name = build_setting('ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME')
      launchimage_name += '.launchimage' if launchimage_name

      icon = nil
      launch_image = nil
      Dir.new(local_path).each do |asset_local_path|
        if asset_local_path == appicon_name && icon.nil?
          base_path = File.join(local_path, asset_local_path)
          icon = find_icon_from_asset_catalog(base_path)
        elsif asset_local_path == launchimage_name && launch_image.nil?
          base_path = File.join(local_path, asset_local_path)
          launch_image = find_launch_image_from_asset_catalog(base_path)
        end
      end

      [icon, launch_image]
    end

    def dest_name(source_path)
      basename = source_path.basename('.*').to_s
      uid = Digest::SHA1.new.update(source_path.to_s).to_s[0, 7]
      basename + '-' + uid + '.o'
    end

    def detect_language(file_type)
      # returns [rule, lang, cpp]

      case file_type
      when 'sourcecode.c.c'
        ['cc', 'c', false]
      when 'sourcecode.c.objc'
        ['cc', 'objective-c', false]
      when 'sourcecode.cpp.cpp'
        ['cc', 'c++', true]
      when 'sourcecode.cpp.objcpp'
        ['cc', 'objective-c++', true]
      when 'sourcecode.swift'
        ['swiftc', 'swift', false]
      when 'sourcecode.c.h', 'sourcecode.glsl', 'sourcecode.javascript'
        return [nil, nil, false]
      else
        raise Informative, "Unknown file type '#{file_type}'"
      end
    end

    def source_build_phase(build_file, file_ref, cc_flags, enable_objc_arc, c_std, cxx_std, builds, objects) # rubocop:disable Metrics/LineLength,AbcSize,CyclomaticComplexity,PerceivedComplexity
      if file_ref.parent.isa != 'PBXGroup'
        puts '[WARN] Orphan file: ' + file.name
        return
      end
      case file_ref
      when Xcodeproj::Project::Object::PBXFileReference # rubocop:disable Lint/EmptyWhen
        # pass through!
      when Xcodeproj::Project::Object::XCVersionGroup
        file_ref.files.each do |inner_file|
          source_build_phase(
            build_file, inner_file, cc_flags, enable_objc_arc, c_std, cxx_std,
            builds, objects
          )
        end
        return
      else
        raise Informative, "Unsupported file class '#{file.class}' of #{file.path}"
      end

      source_path = file_ref.real_path.relative_path_from(Pathname(@base_dir))
      object = File.join(objects_dir, dest_name(source_path))

      settings = build_file.settings
      file_cflags = []
      if settings && settings.key?('COMPILER_FLAGS')
        file_cflags += settings['COMPILER_FLAGS'].split
      end
      if enable_objc_arc
        file_cflags << '-fobjc-arc' unless file_cflags.include?('-fno-objc-arc')
      end

      rule_name, lang, cpp = detect_language(file_ref.last_known_file_type || file_ref.explicit_file_type)

      return unless rule_name

      std = cpp ? cxx_std : c_std
      file_cflags << "-std=#{std}" if std
      file_cflags << "-x #{lang}"

      objects << object

      builds << {
        outputs: [object],
        rule_name: rule_name,
        inputs: [source_path],
        build_variables: {
          'file_cflags' => file_cflags.join(' '),
          'source' => source_path.quote.ninja_escape,
          'cc_flags' => cc_flags
        }
      }
    end

    def sources_build_phase(phase) # rubocop:disable Metrics/MethodLength,AbcSize,CyclomaticComplexity,PerceivedComplexity
      builds = []
      objects = []

      header_dirs = @target.project.header_files.map do |g|
        full_path = g.real_path.relative_path_from(Pathname(@base_dir)).to_s
        File.dirname(full_path)
      end.to_a.uniq

      # build settings
      framework_search_paths = build_setting('FRAMEWORK_SEARCH_PATHS', :array)
      header_search_paths = build_setting('HEADER_SEARCH_PATHS', :array).reject { |value| value == '' }
      user_header_search_paths = build_setting('USER_HEADER_SEARCH_PATHS', :string) || ''
      other_cflags = (build_setting('OTHER_CFLAGS', :array) || []).join(' ')
      cxx_std = build_setting('CLANG_CXX_LANGUAGE_STANDARD', :string)
      c_std = build_setting('GCC_C_LANGUAGE_STANDARD', :string)
      preprocessor_definitions = (build_setting('GCC_PREPROCESSOR_DEFINITIONS', :array) || []).map { |var| "-D#{var}" }.join(' ')

      cxx_std = nil if cxx_std == 'compiler-default'

      framework_dir_options = framework_search_paths.map { |f| "-F#{f}" }.join(' ')
      header_options = (header_search_paths + user_header_search_paths.split + header_dirs).map { |dir| "-I\"#{dir}\"" }.join(' ')

      if build_setting('GCC_PRECOMPILE_PREFIX_HEADER', :bool)
        prefix_pch = build_setting('GCC_PREFIX_HEADER')
        prefix_pch_options = prefix_pch.empty? ? '' : "-include #{prefix_pch}"
      end

      # build sources

      cc_flags = [framework_dir_options,
                  header_options,
                  prefix_pch_options,
                  other_cflags,
                  preprocessor_definitions,
                  a2o_project_flags(:cc)].join(' ')

      enable_objc_arc = build_setting('CLANG_ENABLE_OBJC_ARC', :bool) # default NO

      phase.files.each do |build_file|
        file_ref = build_file.file_ref
        next unless file_ref
        source_build_phase(
          build_file, file_ref, cc_flags, enable_objc_arc, c_std, cxx_std,
          builds, objects
        )
      end

      # stubs
      # FIXME: remove
      Dir.glob("#{xcodeproj_dir}/*_dummy.*").each do |source_path|
        object = File.join(objects_dir, source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))
        objects << object

        file_cflags = '-fobjc-arc '.dup

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
            'source' => source_path.quote.ninja_escape,
            'cc_flags' => cc_flags
          }
        }
      end

      # link
      conf_link_flags = a2o_project_flags(:link)

      builds << {
        outputs: [bitcode_path],
        rule_name: 'link',
        inputs: objects,
        build_variables: {
          'link_flags' => conf_link_flags
        }
      }

      builds
    end

    def hash_key_to_camel(input_hash)
      Hash[
        input_hash.map do |name, value|
          [name.to_s.to_camel, value]
        end
      ]
    end

    def generate_platform_parameters_json
      {
        # Steal proxy urls from runtime_parameters
        http_proxy_url_prefixes: @active_project_config.dig(:runtime_parameters, :emscripten, :http_proxy_url_prefixes) || []
      }.to_json
    end

    def generate_runtime_parameters_json
      # emscripten parameters should be set into the variable `Module`.
      emscripten_parameters = @active_project_config.dig(:runtime_parameters, :emscripten) || {}
      emscripten_parameters[:screen_modes] ||= [{
        width: 640, height: 1136, scale: 2.0
      }]
      emscripten_parameters = hash_key_to_camel(emscripten_parameters)

      # shell parameters should be set into the variable `A2OShell`
      shell_parameters = @active_project_config.dig(:runtime_parameters, :shell) || {}
      shell_parameters[:service_worker_cache_name] = "tombo-#{@target.product_name}-v#{Time.now.to_i}"
      shell_parameters[:paths_to_cache] = [
        'application.asm.js',
        'application.dat',
        'application.js',
        'application.js.mem',
        'Foundation.so.js',
        'application-wasm.js',
        'application-wasm.wasm',
        'Foundation.wasm'
      ]

      shell_parameters = hash_key_to_camel(shell_parameters)

      JSON.pretty_generate(Module: emscripten_parameters,
                           A2OShell: shell_parameters).gsub("\n", '\n')
    end

    def generate_share_library_build_params(dynamic_link_frameworks, extension) # rubocop:disable Metrics/AbcSize,MethodLength
      if dynamic_link_frameworks.empty?
        return {
          builds: [],
          outputs: [],
          options: ['-s MAIN_MODULE=2'],
          dep_paths: []
        }
      end

      builds = []
      outputs = []
      options = ['-s MAIN_MODULE=2 -s LINKABLE=0']
      dep_paths = []

      dynamic_link_frameworks.each do |f|
        source = "#{frameworks_dir}/#{f}.framework/#{f}.#{extension}"
        dest = "#{pre_products_application_dir}/#{f}.#{extension}"
        builds << {
          outputs: [dest],
          rule_name: 'cp_r',
          inputs: [source]
        }
        outputs << dest
      end

      builds << {
        outputs: [shared_library_js_path(extension)],
        rule_name: 'echo',
        inputs: [],
        build_variables: {
          'contents' => 'Module.dynamicLibraries = [' + dynamic_link_frameworks.map { |f| "\"#{f}.#{extension}\"" }.join(',') + '];'
        }
      }

      external_files = dynamic_link_frameworks.map { |f| "#{frameworks_dir}/#{f}.framework/#{f}.#{extension}.externals" }

      builds << {
        outputs: [exported_functions_js_path(extension)],
        rule_name: 'extract_symbol_arrays',
        inputs: external_files,
        build_variables: {
          keys: 'declares',
          extra: '_main _emscripten_pause_main_loop _audioPlayer_stopAll'
        }
      }
      builds << {
        outputs: [exported_variables_js_path(extension)],
        rule_name: 'extract_symbol_arrays',
        inputs: external_files,
        build_variables: {
          keys: 'externs'
        }
      }
      builds << {
        outputs: [library_functions_js_path(extension)],
        rule_name: 'extract_symbol_arrays',
        inputs: external_files,
        build_variables: {
          keys: 'exports'
        }
      }

      options << "--pre-js #{shared_library_js_path(extension)}"
      options << "-s EXPORTED_FUNCTIONS=@#{exported_functions_js_path(extension)}"
      options << "-s EXPORTED_VARIABLES=@#{exported_variables_js_path(extension)}"
      options << "-s LIBRARY_IMPLEMENTED_FUNCTIONS=@#{library_functions_js_path(extension)}"

      dep_paths << shared_library_js_path(extension)
      dep_paths << exported_functions_js_path(extension)
      dep_paths << exported_variables_js_path(extension)
      dep_paths << library_functions_js_path(extension)

      {
        builds: builds,
        outputs: outputs,
        options: options,
        dep_paths: dep_paths
      }
    end

    def application_build_phase # rubocop:disable Metrics/AbcSize,MethodLength
      builds = []

      # platform parameter json
      builds << {
        outputs: [platform_parameters_json_path],
        rule_name: 'echo',
        inputs: [],
        build_variables: {
          contents: generate_platform_parameters_json.shell_quote_escape
        }
      }

      # runtime parameter json
      builds << {
        outputs: [runtime_parameters_json_path],
        rule_name: 'echo',
        inputs: [],
        build_variables: {
          contents: generate_runtime_parameters_json.shell_quote_escape
        }
      }

      # executable

      # generate js compiler flags
      a2o_options = [
        '-v',
        '-s VERBOSE=1',
        '-s LZ4=1',
        '--memory-init-file 1',
        '--separate-asm'
      ]
      a2o_flags = (a2o_project_flags(:html) || '').split
      a2o_options += a2o_flags

      pre_products_outputs_asm = [
        js_mem_path,
        js_path,
        asm_js_path
      ]
      pre_products_outputs_wasm = [
        wasm_js_path,
        wasm_asm_js_path,
        wasm_path
      ]

      if optimized_build?(a2o_flags)
        a2o_options << '--emit-symbol-map'
        pre_products_outputs_asm << js_symbols_path
        pre_products_outputs_wasm << wasm_js_symbols_path
      end

      lib_dirs = build_setting('LIBRARY_SEARCH_PATHS', :array)
      # other_ldflags = (build_setting('OTHER_LDFLAGS', :array) || []).join(' ')
      a2o_options += lib_dirs.map { |dir| "-L#{dir}" }

      # detect emscripten file changes
      dep_paths = file_list("#{emscripten_dir}/src/")

      # data file
      a2o_options << "--pre-js #{data_js_path}"
      dep_paths << data_js_path

      dynamic_link_frameworks = A2OCONF[:xcodebuild][:dynamic_link_frameworks]
      static_link_frameworks = (Set.new(linked_framework_names) + A2OCONF[:xcodebuild][:static_link_frameworks] - dynamic_link_frameworks)

      # static link frameworks
      a2o_options += static_link_frameworks.map { |f| "-framework #{f.ninja_escape}" }
      dep_paths += static_link_frameworks.map { |f| "#{frameworks_dir}/#{f}.framework" }

      # other static libraries
      static_libs = %w[icuuc icui18n icudata crypto]
      a2o_options += static_libs.map { |lib| "-l#{lib}" }
      a2o_options << `PKG_CONFIG_LIBDIR=#{emscripten_dir}/system/lib/pkgconfig:#{emscripten_dir}/system/local/lib/pkgconfig pkg-config freetype2 --libs`.strip
      # TODO: dpe_paths += static_libs.map{ |lib| real path of lib }

      # objects
      linked_objects = static_libraries_from_other_projects + [bitcode_path]

      # asm
      asm_shared_lib_params = generate_share_library_build_params(dynamic_link_frameworks, 'so.js')
      asm_a2o_options = a2o_options + asm_shared_lib_params[:options]
      asm_dep_paths = dep_paths + asm_shared_lib_params[:dep_paths]
      builds += asm_shared_lib_params[:builds]

      builds << {
        outputs: pre_products_outputs_asm,
        rule_name: 'compose',
        inputs: linked_objects + asm_dep_paths,
        build_variables: {
          'options' => asm_a2o_options.join(' '),
          'linked_objects' => linked_objects.map { |o| '"' + o.ninja_escape + '"' }.join(' '),
          'js_path' => js_path.ninja_escape.quote
        }
      }

      # wasm
      wasm_shared_lib_params = generate_share_library_build_params(dynamic_link_frameworks, 'wasm')
      wasm_a2o_options = a2o_options + wasm_shared_lib_params[:options] + ['-s BINARYEN=1']
      wasm_dep_paths = dep_paths + wasm_shared_lib_params[:dep_paths]
      builds += wasm_shared_lib_params[:builds]

      builds << {
        outputs: pre_products_outputs_wasm,
        rule_name: 'compose',
        inputs: linked_objects + wasm_dep_paths + dependent_target_names,
        build_variables: {
          'options' => wasm_a2o_options.join(' '),
          'linked_objects' => linked_objects.map { |o| '"' + o.ninja_escape + '"' }.join(' '),
          'js_path' => wasm_js_path.ninja_escape.quote
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

      products_inputs = pre_products_outputs_asm + pre_products_outputs_wasm + asm_shared_lib_params[:outputs] + wasm_shared_lib_params[:outputs] + [
        data_path,
        platform_parameters_json_path,
        runtime_parameters_json_path
      ]
      products_inputs.concat(@icon_output_paths) if @icon_output_paths
      products_inputs << @launch_image_output_path if @launch_image_output_path
      products_inputs.concat(@ogp_image_output_paths) if @ogp_image_output_paths

      products_outputs = products_inputs.map do |path|
        path.sub("#{@target.unique_name}/pre_products", 'products')
      end
      products_outputs << products_html_path
      products_outputs << products_service_worker_js_path

      builds << {
        outputs: products_outputs,
        rule_name: 'generate_products',
        inputs: products_inputs + [
          application_template_html_path,
          service_worker_template_js_path
        ],
        build_variables: {
          'pre_products_dir' => pre_products_dir.ninja_escape.quote,
          'products_dir' => products_dir.ninja_escape.quote,
          'products_application_dir' => products_application_dir.ninja_escape.quote,
          'shell_html_path' => application_template_html_path.ninja_escape.quote,
          'service_worker_js_path' => service_worker_template_js_path.ninja_escape.quote
        }
      }

      # copy shell.html resources
      out_dir = build_dir
      shell_files = Ninja.file_recursive_copy(shell_files_source_dir, out_dir, shell_template_dir)
      builds += shell_files[:builds]

      # add a symbolic link
      shell_symlink = Ninja.file_link('../../shell_files', products_shell_files_link_dir)
      builds += shell_symlink[:builds]

      builds << {
        outputs: [phony_target_name],
        rule_name: 'phony',
        inputs: products_outputs + shell_files[:outputs] + shell_symlink[:outputs]
      }

      builds
    end

    def static_library_build_phase
      builds = []

      library_path = "#{pre_products_dir}/#{@target.product_reference.path}"

      builds << {
        outputs: [library_path],
        rule_name: 'archive',
        inputs: [bitcode_path] + dependent_target_names,
        build_variables: {
          objects: bitcode_path.ninja_escape
        }
      }

      builds << {
        outputs: [phony_target_name],
        rule_name: 'phony',
        inputs: [library_path]
      }

      builds
    end

    def linked_framework_names
      framework_names = []
      @target.frameworks_build_phase.files.each do |file|
        file_ref = file.file_ref
        next unless file_ref.is_a?(Xcodeproj::Project::Object::PBXFileReference)

        # TODO: handle .dylib
        name = file_ref.name
        if name && name.end_with?('.framework') && (file_ref.source_tree == 'SDKROOT' || file_ref.source_tree == 'DEVELOPER_DIR')
          framework_names << File.basename(name, '.framework')
        end
      end

      framework_names
    end

    def static_libraries_from_other_projects
      libs = []

      @target.frameworks_build_phase.files.each do |file|
        file_ref = file.file_ref
        remote_target = case file_ref
                        when Xcodeproj::Project::Object::PBXFileReference
                          if file_ref.source_tree == 'BUILT_PRODUCTS_DIR'
                            @target.project.workspace.library_to_targert_map[file_ref.path]
                          end
                        when Xcodeproj::Project::Object::PBXReferenceProxy
                          proxy = file_ref.remote_ref
                          proxy.remote_target
                        end

        if remote_target
          remote_a2o_target = A2OTarget.new(remote_target, @build_config.name, @active_project_config, @a2o_target_name, @a2obrew_path, @base_dir)
          libs << "#{remote_a2o_target.pre_products_dir}/#{file_ref.path}"
        end
      end

      libs
    end

    def frameworks_build_phase(_phase)
      []
    end

    def header_build_phase(_phase)
      []
    end

    def shell_script_build_phase(_phase)
      []
    end

    def copy_files_phase(_phase)
      []
    end

    def after_build_phase
      []
    end

    def unit_test_build_phase # rubocop:disable Metrics/AbcSize,MethodLength
      builds = []

      # runtime parameter json
      builds << {
        outputs: [runtime_parameters_json_path],
        rule_name: 'echo',
        inputs: [],
        build_variables: {
          contents: generate_runtime_parameters_json.shell_quote_escape
        }
      }

      # executable

      # generate js compiler flags
      a2o_options = [
        '-v',
        '-s VERBOSE=1',
        '-s LZ4=1',
        '--memory-init-file 1',
        '--separate-asm'
      ]
      a2o_flags = (a2o_project_flags(:html) || '').split
      a2o_options += a2o_flags

      pre_products_outputs_asm = [
        js_mem_path,
        js_path,
        asm_js_path
      ]

      lib_dirs = build_setting('LIBRARY_SEARCH_PATHS', :array)
      # other_ldflags = (build_setting('OTHER_LDFLAGS', :array) || []).join(' ')
      a2o_options += lib_dirs.map { |dir| "-L#{dir}" }

      # detect emscripten file changes
      dep_paths = file_list("#{emscripten_dir}/src/")

      # data file
      a2o_options << "--pre-js #{data_js_path}"
      dep_paths << data_js_path

      # NO dynamic link!!!!
      static_link_frameworks = Set.new(linked_framework_names) + A2OCONF[:xcodebuild][:static_link_frameworks] + A2OCONF[:xcodebuild][:dynamic_link_frameworks]
      static_link_frameworks << 'XCTest'

      # static link frameworks
      a2o_options += static_link_frameworks.map { |f| "-framework #{f.ninja_escape}" }
      dep_paths += static_link_frameworks.map { |f| "#{frameworks_dir}/#{f}.framework" }

      # other static libraries
      static_libs = %w[icuuc icui18n icudata crypto]
      a2o_options += static_libs.map { |lib| "-l#{lib}" }
      a2o_options << `PKG_CONFIG_LIBDIR=#{emscripten_dir}/system/lib/pkgconfig:#{emscripten_dir}/system/local/lib/pkgconfig pkg-config freetype2 --libs`.strip
      # TODO: dpe_paths += static_libs.map{ |lib| real path of lib }

      # objects
      linked_objects = static_libraries_from_other_projects + [bitcode_path] + ["#{a2obrew_dir}/unit_test/test_main.m"]

      # asm
      builds << {
        outputs: pre_products_outputs_asm,
        rule_name: 'compose',
        inputs: linked_objects + dep_paths + dependent_target_names,
        build_variables: {
          'options' => a2o_options.join(' '),
          'linked_objects' => linked_objects.map { |o| '"' + o.ninja_escape + '"' }.join(' '),
          'js_path' => js_path.ninja_escape.quote
        }
      }

      # copy pre_products to products

      unit_test_inputs = pre_products_outputs_asm + [
        data_path,
        runtime_parameters_json_path
      ]

      unit_test_outputs = unit_test_inputs.map do |path|
        path.sub("#{@target.unique_name}/pre_products", 'unit_test')
      end
      unit_test_outputs << unit_test_html_path
      unit_test_outputs << unit_test_service_worker_js_path

      builds << {
        outputs: unit_test_outputs,
        rule_name: 'generate_products',
        inputs: unit_test_inputs + [
          application_template_html_path,
          service_worker_template_js_path
        ],
        build_variables: {
          'pre_products_dir' => pre_products_dir.ninja_escape.quote,
          'products_dir' => unit_test_dir.ninja_escape.quote,
          'products_application_dir' => unit_test_application_dir.ninja_escape.quote,
          'shell_html_path' => application_template_html_path.ninja_escape.quote,
          'service_worker_js_path' => service_worker_template_js_path.ninja_escape.quote
        }
      }

      # copy shell.html resources
      out_dir = build_dir
      shell_files = Ninja.file_recursive_copy(shell_files_source_dir, out_dir, shell_template_dir)
      builds += shell_files[:builds]

      # add a symbolic link
      shell_symlink = Ninja.file_link('../../shell_files', unit_test_shell_files_link_dir)
      builds += shell_symlink[:builds]

      builds << {
        outputs: [phony_target_name],
        rule_name: 'phony',
        inputs: unit_test_outputs + shell_files[:outputs] + shell_symlink[:outputs]
      }

      builds
    end

    # utils
    def build_setting(prop, type = nil)
      env = {
        'BUILD_DIR' => build_dir,
        'CONFIGURATION' => @build_config.name,
        'EFFECTIVE_PLATFORM_NAME' => 'emscripten',
        'PROJECT_DIR' => xcodeproj_dir,
        'SRCROOT' => xcodeproj_dir,
        'PLATFORM_NAME' => 'emscripten',
        'SDKROOT' => emscripten_dir,
        'SDK_DIR' => '', # FIXME: currently ignores
        'DEVELOPER_FRAMEWORKS_DIR' => '', # FIXME: currently ignores
        'MYPROJ_HOME' => '', # FIXME: currently ignores
        'TARGET_NAME' => @target.name
      }

      if env.key?(prop)
        env[prop]
      else
        expand(@build_config.resolve_build_setting(prop), type)
      end
    end

    def expand(value, type = nil)
      if value.is_a?(Array)
        value.delete('$(inherited)')
        value.map do |v|
          expand(v)
        end
      else
        case type
        when :bool
          value == 'YES'
        when :array
          if value.nil?
            []
          else
            [expand(value)]
          end
        else
          if value.nil?
            nil
          else
            resolve_macro(value)
          end
        end
      end
    end

    def resolve_macro(value)
      value.gsub(/\$(\{|\()?([A-Za-z0-9_]+)(\}|\))?/) do |m|
        varname = Regexp.last_match(2)

        value = build_setting(varname)

        raise Informative, "Not support for #{m}" unless value

        value
      end
    end

    def get_nib_paths_from_storyboard(storyboard_path)
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

    def system_framework_resources
      builds = []
      outputs = []
      out_dir = framework_bundle_dir

      Dir.glob("#{frameworks_dir}/*.framework/Resources/*") do |path|
        f = Ninja.file_recursive_copy(path, out_dir, frameworks_dir)
        builds += f[:builds]
        outputs += f[:outputs]
      end

      { builds: builds, outputs: outputs }
    end

    def optimized_build?(flags)
      !flags.include?('-g') && (
        flags.include?('-O2') ||
        flags.include?('-O3') ||
        flags.include?('-Os') ||
        flags.include?('-Oz'))
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
