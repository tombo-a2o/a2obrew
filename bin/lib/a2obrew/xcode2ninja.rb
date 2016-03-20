require 'xcodeproj'
require 'fileutils'
require 'pathname'
require 'rexml/document' # For parsing storyboard

# rubocop:disable Metrics/ParameterLists

module A2OBrew
  LINK_FRAMEWORKS = %w(
    UIKit Security ImageIO AudioToolbox CommonCrypto SystemConfiguration
    CoreGraphics QuartzCore AppKit CFNetwork OpenGLES Onyx2D CoreText
    Social AVFoundation
  ).freeze
  # NOTE: --separate-metadata on file packager was buggy so we decided not to use it
  SEPARATE_METADATA = false

  class Xcode2Ninja # rubocop:disable Metrics/ClassLength
    def initialize(xcodeproj_path)
      self.xcodeproj_path = xcodeproj_path
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
      builds, rules = generate_build_rules(xcodeproj, target, build_config, active_project_config, a2o_target)
      write_ninja_build(output_dir, target, build_config, a2o_target, builds, rules)
    end

    def generate_build_rules(xcodeproj, target, build_config, active_project_config, a2o_target) # rubocop:disable Metrics/MethodLength,Metrics/LineLength
      builds = []
      rules = basic_rules

      target.build_phases.each do |phase|
        e = case phase
            when Xcodeproj::Project::Object::PBXResourcesBuildPhase
              resources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
            when Xcodeproj::Project::Object::PBXSourcesBuildPhase
              sources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
            when Xcodeproj::Project::Object::PBXFrameworksBuildPhase
              frameworks_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
            when Xcodeproj::Project::Object::PBXShellScriptBuildPhase
              shell_script_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target)
            else
              raise Informative, "Don't support the phase #{phase.class.name}."
            end

        builds += e[0]
        rules += e[1]
      end

      [builds, rules]
    end

    def write_ninja_build(output_dir, _target, _build_config, a2o_target, builds, rules) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/LineLength
      FileUtils.mkdir_p(output_dir) unless File.directory?(output_dir)

      path = File.join(output_dir, "#{a2o_target}.ninja.build")
      File.open(path, 'w:UTF-8') do |f|
        rules.each do |r|
          f.puts "rule #{r[:rule_name]}"
          f.puts "  description = #{r[:description]}" if r[:description]
          f.puts "  command = #{r[:command]}"
          f.puts ''
        end

        builds.each do |b|
          f.puts "build #{b[:outputs].join(' ')}: #{b[:rule_name]} #{b[:inputs].join(' ')}"
          build_variables = b[:build_variables] || []
          build_variables.each do |k, v|
            f.puts "  #{k} = #{v}"
          end
          f.puts ''
        end
      end

      path
    end

    def basic_rules
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
        }
      ]
    end

    # paths

    def build_dir(a2o_target)
      "build/#{a2o_target}"
    end

    def packager_target_dir(a2o_target)
      "#{build_dir(a2o_target)}/package"
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

    def objects_dir(a2o_target)
      "#{build_dir(a2o_target)}/objects"
    end

    def emscripten_dir
      ENV['EMSCRIPTEN']
    end

    def frameworks_dir
      "#{emscripten_dir}/system/frameworks"
    end

    def data_path(target, a2o_target)
      "#{build_dir(a2o_target)}/#{target.product_name}.dat"
    end

    def data_js_path(target, a2o_target)
      "#{build_dir(a2o_target)}/#{target.product_name}Data.js"
    end

    def data_js_metadata_path(target, a2o_target)
      "#{data_js_path(target, a2o_target)}.metadata"
    end

    def html_path(target, a2o_target)
      "#{build_dir(a2o_target)}/#{target.product_name}.html"
    end

    def html_mem_path(target, a2o_target)
      "#{html_path(target, a2o_target)}.mem"
    end

    def js_path(target, a2o_target)
      "#{build_dir(a2o_target)}/#{target.product_name}.js"
    end

    def bitcode_path(target, a2o_target)
      "#{build_dir(a2o_target)}/#{target.product_name}.bc"
    end

    def a2o_project_flags(active_project_config, rule)
      # {
      #   flags: {
      #     cc: '-O0',
      #     link: '-l ababa',
      #     html: '-s WEIRD=1'
      #   }
      # }
      # TODO: Use Ruby 2.3 and Hash#dig
      flags = active_project_config[:flags]
      flags[rule] if flags
    end

    # phases

    def resources_build_phase(_xcodeproj, target, build_config, phase, _active_project_config, a2o_target) # rubocop:disable Metrics/MethodLength,Metrics/AbcSize,Metrics/LineLength
      # FIXME: reduce Metrics/AbcSize,Metrics/MethodLength
      builds = []
      rules = []
      resources = []
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
          local_path = File.join(file.parents.map(&:path).select { |path| path }, file.path)
          remote_path = File.join(resources_dir(a2o_target), file.path)

          if File.extname(file.path) == '.storyboard'
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
                'temp_dir' => tmp_path
              }
            }
            resources += nib_paths
          else
            f = file_recursive_copy(local_path, remote_path)
            builds += f[:builds]
            resources += f[:outputs]
          end
        end
      end

      infoplist_path = build_config.build_settings['INFOPLIST_FILE']
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
      t = data_path(target, a2o_target)
      j = data_js_path(target, a2o_target)
      outputs = [t, j]
      options = ''
      if SEPARATE_METADATA
        outputs << data_js_metadata_path(target, a2o_target)
        options += ' --separate-metadata'
      end
      builds << {
        outputs: outputs,
        rule_name: 'file_packager',
        inputs: resources,
        build_variables: {
          'target' => t,
          'js_output' => j,
          'options' => options
        }
      }

      # add rules
      rules << {
        rule_name: 'ibtool',
        description: 'ibtool ${in}',
        command: "ibtool --errors --warnings --notices --module #{target.product_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --compilation-directory `dirname ${temp_dir}` ${in} && ibtool --errors --warnings --notices --module #{target.product_name} --target-device iphone --minimum-deployment-target 9.0 --output-format human-readable-text --link #{resources_dir(a2o_target)} ${temp_dir}" # rubocop:disable LineLength
      }

      # FIXME: try --lz4 option after upgrading emscripten
      # NOTE: Could we use --use-preload-cache ?
      rules << {
        rule_name: 'file_packager',
        description: 'execute file packager to ${target}',
        command: "python #{emscripten_dir}/tools/file_packager.py ${target} --preload #{packager_target_dir(a2o_target)}@/ --js-output=${js_output} --no-heap-copy ${options}" # rubocop:disable LineLength
      }

      [builds, rules]
    end

    def file_recursive_copy(in_dir, out_dir) # rubocop:disable Metrics/MethodLength
      builds = []
      outputs = []

      in_path = Pathname(in_dir)

      in_path.find do |path|
        next unless path.file?

        rel_path = path.relative_path_from(in_path)
        output_path = File.join(out_dir, rel_path.to_s)
        builds << {
          outputs: [output_path],
          rule_name: 'cp_r',
          inputs: [path.to_s]
        }
        outputs << output_path
      end

      {
        builds: builds,
        outputs: outputs
      }
    end

    # rubocop:disable Metrics/LineLength
    def sources_build_phase(xcodeproj, target, build_config, phase, active_project_config, a2o_target) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      # FIXME: reduce Metrics/AbcSize,Metrics/MethodLength
      builds = []
      rules = []
      objects = []

      header_dirs = xcodeproj.main_group.recursive_children.select { |g| g.path && File.extname(g.path) == '.h' }.map do |g|
        full_path = File.join((g.parents + [g]).map(&:path).select { |path| path })
        File.dirname(full_path)
      end.to_a.uniq

      # build settings
      bs = build_config.build_settings
      lib_dirs = expand(bs['LIBRARY_SEARCH_PATHS'], :array)
      framework_search_paths = expand(bs['FRAMEWORK_SEARCH_PATHS'], :array)
      header_search_paths = expand(bs['HEADER_SEARCH_PATHS'], :array)

      lib_options = lib_dirs.map { |dir| "-L#{dir}" }.join(' ')
      framework_dir_options = framework_search_paths.map { |f| "-F#{f}" }.join(' ')
      header_options = (header_dirs + header_search_paths).map { |dir| "-I./#{dir}" }.join(' ')

      if expand(bs['GCC_PRECOMPILE_PREFIX_HEADER'], :bool)
        prefix_pch = bs['GCC_PREFIX_HEADER']
        prefix_pch_options = "-include #{prefix_pch}"
      end

      # build sources

      cc_flags = [framework_dir_options, header_options, lib_options, prefix_pch_options].join(' ')
      conf_cc_flags = a2o_project_flags(active_project_config, :cc)

      rules << {
        rule_name: 'cc',
        description: 'compile ${source} to ${out}',
        command: "a2o -Wno-warn-absolute-paths #{cc_flags} ${file_cflags} -c ${source} -o ${out} #{conf_cc_flags}"
      }

      phase.files_references.each do |file|
        source_path = File.join(file.parents.map(&:path).select { |path| path }, file.path)
        object = File.join(objects_dir(a2o_target), source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))

        objects << object

        settings = file.build_files[0].settings
        file_cflags = []
        if settings && settings.key?('COMPILER_FLAGS')
          file_cflags += expand(settings['COMPILER_FLAGS'], :array)
        end
        file_cflags << '-fobjc-arc' unless file_cflags.include?('-fno-objc-arc')

        builds << {
          outputs: [object],
          rule_name: 'cc',
          # TODO: dependency of framework
          inputs: [source_path, prefix_pch],
          build_variables: {
            'file_cflags' => file_cflags.join(' '),
            'source' => source_path
          }
        }
      end

      # stubs
      # FIXME: remove
      Dir.glob('*_dummy.m').each do |source_path|
        object = File.join(objects_dir(a2o_target), source_path.gsub(/\.[A-Za-z0-9]+$/, '.o'))
        objects << object

        builds << {
          outputs: [object],
          rule_name: 'cc',
          inputs: [source_path, prefix_pch],
          build_variables: {
            'source' => source_path
          }
        }
      end

      # link
      conf_link_flags = a2o_project_flags(active_project_config, :link)

      rules << {
        rule_name: 'link',
        description: 'link to ${out}',
        command: "llvm-link -o ${out} ${in} #{conf_link_flags}"
      }

      builds << {
        outputs: [bitcode_path(target, a2o_target)],
        rule_name: 'link',
        inputs: objects
      }

      # executable

      # detect emscripten file changes
      dep_paths = file_list("#{emscripten_dir}/src/")
      LINK_FRAMEWORKS.each do |f|
        dep_paths.concat(file_list("#{frameworks_dir}/#{f}.framework/#{f}"))
      end

      # generate html
      conf_html_flags = a2o_project_flags(active_project_config, :html)

      rules << {
        rule_name: 'html',
        description: 'generate executables: ${out}',
        command: "EMCC_DEBUG=1 a2o -v ${framework_options} ${lib_options} -s NATIVE_LIBDISPATCH=1 --emrun -o #{html_path(target, a2o_target)} ${linked_objects} --pre-js ${pre_js} -licuuc -licui18n #{conf_html_flags}"
      }

      builds << {
        outputs: [html_path(target, a2o_target), html_mem_path(target, a2o_target), js_path(target, a2o_target)],
        rule_name: 'html',
        inputs: [data_js_path(target, a2o_target), bitcode_path(target, a2o_target)] + dep_paths,
        build_variables: {
          'pre_js' => data_js_path(target, a2o_target),
          'linked_objects' => bitcode_path(target, a2o_target),
          'framework_options' => LINK_FRAMEWORKS.map { |f| "-framework #{f}" }.join(' '),
          'lib_options' => `PKG_CONFIG_LIBDIR=#{emscripten_dir}/system/lib/pkgconfig:#{emscripten_dir}/system/local/lib/pkgconfig pkg-config freetype2 --libs`.strip + ' -lcrypto'
        }
      }

      [builds, rules]
    end
    # rubocop:enable Metrics/LineLength

    def frameworks_build_phase(_xcodeproj, _target, _build_config, _phase, _active_project_config, _a2o_target)
      # FIXME: Implement
      [[], []]
    end

    def shell_script_build_phase(_xcodeproj, _target, _build_config, _phase, _active_project_config, _a2o_target)
      # FIXME: Implement
      [[], []]
    end

    # utils

    def expand(value, type = nil) # rubocop:disable Metrics/MethodLength,Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity,Metrics/LineLength
      if value.is_a?(Array)
        value = value.reject do |v|
          v == '$(inherited)'
        end

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
            # rubocop:disable Metrics/BlockNesting
            value.gsub(/\$\([A-Za-z0-9_]+\)/) do |m|
              case m
              when '$(PROJECT_DIR)'
                xcodeproj_dir
              when '$(SDKROOT)'
                # FIXME: currently ignores
                ''
              when '$(DEVELOPER_FRAMEWORKS_DIR)'
                # FIXME: currently ignores
                ''
              else
                raise Informative, "Not support for #{m}"
              end
            end
          end
        end
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
      out_prefix = framework_bundle_dir(a2o_target)
      builds = []
      outputs = []
      Dir.glob("#{frameworks_dir}/*.framework/Resources/") do |path|
        rel_path = path[(frameworks_dir.length + 1)..-1]
        out_path = File.join(out_prefix, rel_path)

        f = file_recursive_copy(path, out_path)
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
