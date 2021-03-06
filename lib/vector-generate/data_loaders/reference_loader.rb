module VectorGenerate
  module DataLoaders
    module ReferenceLoader
      extend self

      def load!(dir)
        cmd = "cue export #{dir}/docs/*.cue " +
          "#{dir}/docs/reference/*.cue " +
          "#{dir}/docs/reference/components/*.cue " +
          "#{dir}/docs/reference/data_model/*.cue " +
          "#{dir}/docs/reference/installation/*.cue " +
          "#{dir}/docs/reference/installation/_interfaces/role_implementations/*.cue " +
          "#{dir}/docs/reference/installation/_interfaces/*.cue " +
          "#{dir}/docs/reference/installation/downloads/*.cue " +
          "#{dir}/docs/reference/installation/operating_systems/*.cue " +
          "#{dir}/docs/reference/installation/package_managers/*.cue " +
          "#{dir}/docs/reference/installation/platforms/*.cue " +
          "#{dir}/docs/reference/installation/roles/*.cue " +
          "#{dir}/docs/reference/releases/*.cue " +
          "#{dir}/docs/reference/remap/*.cue " +
          "#{dir}/docs/reference/remap/concepts/*.cue " +
          "#{dir}/docs/reference/remap/errors/*.cue " +
          "#{dir}/docs/reference/remap/expressions/*.cue " +
          "#{dir}/docs/reference/remap/features/*.cue " +
          "#{dir}/docs/reference/remap/functions/*.cue " +
          "#{dir}/docs/reference/remap/literals/*.cue " +
          "#{dir}/docs/reference/remap/principles/*.cue " +
          "#{dir}/docs/reference/remap/syntax/*.cue " +
          "#{dir}/docs/reference/components/sources/*.cue " +
          "#{dir}/docs/reference/components/transforms/*.cue " +
          "#{dir}/docs/reference/components/sinks/*.cue " +
          "#{dir}/docs/reference/services.cue " +
          "#{dir}/docs/reference/services/*.cue"

        json = `#{cmd}`
        ref = JSON.parse(json)
        ref_components = ref.fetch("components")
        ref_configuration = ref.fetch("configuration")
        api = ref.fetch("api")
        api["configuration"] = transform_schema(api.fetch("configuration"))

        ref.fetch("configuration")

        meta = {
          "api" => api,
          "cli" => ref.fetch("cli"),
          "configuration" => {
            "configuration" => transform_schema(ref_configuration.fetch("configuration")),
            "how_it_works" => ref_configuration.fetch("how_it_works")
          },
          "data_model" => {
            "schema" => transform_schema(ref.fetch("data_model").fetch("schema"))
          },
          "installation" => ref.fetch("installation"),
          "releases" => ref.fetch("releases"),
          "remap" => ref.fetch("remap"),
          "services" => ref.fetch("services"),
          "sources" => {},
          "transforms" => {},
          "sinks" => {},
          "team" => ref.fetch("team"),
          "urls" => ref.fetch("urls")
        }

        ref_components.fetch("sources").each do |k, v|
          meta["sources"][k] = transform_component(v)
        end

        ref_components.fetch("transforms").each do |k, v|
          meta["transforms"][k] = transform_component(v)
        end

        ref_components.fetch("sinks").each do |k, v|
          meta["sinks"][k] = transform_component(v)
        end

        meta
      end

      private
        def transform_component(component)
          classes = component.fetch("classes")
          configuration = component.fetch("configuration")
          env_vars = component["env_vars"] || {}
          examples = component["examples"] || []
          features = component.fetch("features")
          function = (features.keys - ["buffer", "healthcheck", "multiline"]).first
          output = component["output"]
          input = component["input"]
          support = component.fetch("support")
          targets = support.fetch("targets")

          new_component =
            {
              "title" => component.fetch("title"),
              "common" => classes.fetch("commonly_used"),
              "short_description" => (component["description"] ? component["description"].gsub("\n", " ") : nil),
              "egress_method" => classes["egress_method"],
              "env_vars" => {},
              "examples" => [],
              "fields" => {},
              "features" => [],
              "features_raw" => features,
              "function_category" => function,
              "how_it_works" => component["how_it_works"],
              "installation" => component["installation"],
              "only_operating_systems" => [],
              "stateful" => classes.fetch("stateful"),
              "status" => classes.fetch("development"),
              "support" => support,
              "telemetry" => component["telemetry"],
              "options" => {}
            }

          if targets.fetch("aarch64-unknown-linux-gnu") || targets.fetch("x86_64-unknown-linux-gnu")
            new_component["only_operating_systems"] << "Linux"
          end

          if targets.fetch("x86_64-apple-darwin")
            new_component["only_operating_systems"] << "macOS"
          end

          if targets.fetch("x86_64-pc-windows-msv")
            new_component["only_operating_systems"] << "Windows"
          end

          if classes["delivery"]
            new_component["delivery_guarantee"] = classes["delivery"]
          end

          if classes["deployment_roles"]
            new_component["strategies"] =
              classes["deployment_roles"].collect do |r|
                r == "aggregator" ? "service" : r
              end
          end

          if input && input["logs"]
            new_component["input_types"] ||= []
            new_component["input_types"] << "log"
          end

          if input && input["metrics"]
            new_component["input_types"] ||= []
            new_component["input_types"] << "metric"
          end

          if output && output.key?("logs")
            new_component["output_types"] ||= []
            new_component["output_types"] << "log"
          end

          if output && output.key?("metrics")
            new_component["output_types"] ||= []
            new_component["output_types"] << "metric"
          end

          types = new_component["input_types"] || new_component["output_types"] || []

          from = features.fetch(function)["from"]
          format = features.fetch(function)["format"]
          runtime = features.fetch(function)["runtime"]
          to = features.fetch(function)["to"]
          target = from || format || runtime || to || {}
          service = target["service"] || {}
          service_name = service["name"]
          thing = service["thing"] || service["name"]
          url = service["url"]
          versions = service["versions"]

          new_component["noun"] = thing
          new_component["short_description"] ||= "#{function.pluralize.sub(/^./, &:upcase)} #{types.collect(&:pluralize).join(" and ")}" + (service_name ? ((!to.nil? ? " to " : " from ") + (url ? "[#{service_name}](#{url})." : "#{service_name}")) : "").freeze

          new_component["features"] ||= []
          new_component["features"] << new_component["short_description"]

          features.fetch("descriptions").each do |k, v|
            new_component["features"] << v
          end

          if versions
            new_component["support"]["requirements"] << (url ? "[#{service_name}](#{url})" : "#{service_name}") + " #{versions} is required."
          end

          if component.fetch("kind") != "source"
            new_component["output_types"] ||= []
          end

          if output && output["logs"] && output["logs"].values.first
            new_component["fields"]["log"] = {"fields" => {}}
            fields = output["logs"].values.first["fields"] || {}

            fields.each do |k, v|
              new_component["fields"]["log"]["fields"][k] = transform_option(v)
            end
          end

          if output && output["metrics"]
            new_component["fields"]["metric"] = output["metrics"]
          end

          examples.each do |example|
            new_component["examples"] << transform_example(component, example)
          end

          configuration.each do |k, v|
            new_component["options"][k] = transform_option(v)
          end

          env_vars.each do |k, v|
            new_component["env_vars"][k] = transform_option(v)
          end

          new_component
        end

        def transform_option(option)
          type_name = option.fetch("type").keys.first
          type = option.fetch("type").fetch(type_name).clone
          enum = type["enum"] || {}
          examples = type["examples"] || []

          if type_name == "array"
            sub_type = type.fetch("items").fetch("type")
            sub_type_name = sub_type.keys.first == "object" ? "table" : sub_type.keys.first
            type_name = "[" + sub_type_name + "]"

            if enum.empty? && examples.empty? && !sub_type.values.first["examples"].nil? && !sub_type.values.first["examples"].empty?
              examples = [sub_type.values.first["examples"]]
            end

            if sub_type_name == "table"
              type["options"] = sub_type.values.first.fetch("options")
            end
          end

          if type_name == "object"
            type_name = "table"
          end

          new_option =
            {
              "syntax" => type["syntax"],
              "type" => type_name,
              "description" => option.fetch("description")
            }

          if option["category"]
            new_option["category"] = option["category"]
          end

          if option["common"]
            new_option["common"] = option["common"]
          end

          if !type["default"].nil?
            new_option["default"] = type["default"]
          end

          if type["enum"]
            new_option["enum"] = type["enum"]
          end

          if !examples.empty? && !examples.flatten.empty?
            new_option["examples"] = if option.fetch("name").start_with?("<") || option.fetch("name").start_with?("*")
              examples.collect do |example|
                {
                  option.fetch("name") => example
                }
              end
            else
              examples
            end
          end

          if option["groups"]
            new_option["groups"] = option["groups"]
          end

          if option["relevant_when"]
            new_option["relevant_when"] = option["relevant_when"]
          end

          if option["required"]
            new_option["required"] = option["required"]
          end

          if option["sort"]
            new_option["sort"] = option["sort"]
          end

          if type["unit"]
            new_option["unit"] = type["unit"]
          end

          if option["warnings"]
            new_option["warnings"] =
              option["warnings"].collect do |warning|
                {
                  "text" => warning,
                  "visibility_level" => "option"
                }
              end
          end


          if type_name == "table" || type_name == "[table]"
            new_option["children"] = {}

            type.fetch("options").each do |k, v|
              new_option["children"][k] = transform_option(v)
            end
          end

          new_option
        end

        def transform_example(component, example)
          input = example.fetch("input")
          output = example.fetch("output")

          input_text =
            if input && !input.is_a?(String)
              type = input.is_a?(Hash) ? input.keys.first : input.fetch(0).keys.first
              data = input.is_a?(Hash) ? input.values.first : input.collect { |o| o.values.first }

              <<~EOF
              Given the following [Vector #{type} event][docs.data-model.#{type}]:

              ```json
              #{JSON.pretty_generate(data)}
              ```
              EOF
            elsif input
              <<~EOF
              Given the following input:

              #{input}
              EOF
            else
              nil
            end

          output_text =
            if output && !output.is_a?(String)
              type = output.is_a?(Hash) ? output.keys.first : output.fetch(0).keys.first
              data = output.is_a?(Hash) ? output.values.first : output.collect { |o| o.values.first }

              <<~EOF
              The following [Vector #{type} event][docs.data-model.#{type}] will be output:

              ```json
              #{JSON.pretty_generate(data)}
              ```
              EOF
            elsif output
              <<~EOF
              The following output will be produced:

              #{output}
              EOF
            else
              "No events will be output"
            end

          {
            "label" => example.fetch("title"),
            "body" =>
              <<~EOF
              #{input_text}
              And the following configuration:

              ```toml title="vector.toml"
              [#{component.fetch("kind").pluralize}.#{component.fetch("type")}]
              type = "#{component.fetch("type")}"
              #{example.fetch("configuration").to_toml(hash_style: :flatten).strip}
              ```

              #{output_text}
              EOF
          }
        end

        def transform_schema(schema)
          transformed_schema = {}

          schema.each do |name, option|
            transformed_schema[name] = transform_option(option)
          end

          transformed_schema
        end
    end
  end
end