#encoding: utf-8

require_relative "component"
require_relative "fields"

module VectorGenerate
  class Metadata
    class Transform < Component
      attr_reader :allow_you_to_description,
        :fields,
        :input_types,
        :output_types

      def initialize(hash)
        super(hash)

        # init

        @allow_you_to_description = hash["allow_you_to_description"]
        @fields = OpenStruct.new
        @input_types = hash.fetch("input_types")
        @output_types = hash.fetch("output_types")

        # fields

        fields = hash["fields"] || {}

        if fields["log"]
          @fields.log = Fields.new(fields["log"])
        end

        if fields["metric"]
          @fields.metric = fields.fetch("metric").to_struct
        end
      end

      def can_receive_from?(component)
        case component
        when Source
          component.output_types.intersection(input_types).any?
        when Transform
          component.output_types.intersection(input_types).any?
        when Sink
          false
        else
          raise ArgumentError.new("Uknown component type: #{component.class.name}")
        end
      end

      def can_send_to?(component)
        case component
        when Source
          false
        when Transform
          component.input_types.intersection(output_types).any?
        when Sink
          component.input_types.intersection(output_types).any?
        else
          raise ArgumentError.new("Uknown component type: #{component.class.name}")
        end
      end

      def log_fields_list
        @log_fields_list ||= fields.log ? fields.log.fields_list : []
      end

      def to_h
        super.merge(
          inpuut_types: input_types,
          output_types: output_types
        )
      end
    end
  end
end
