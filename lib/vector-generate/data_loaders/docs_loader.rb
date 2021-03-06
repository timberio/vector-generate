require 'front_matter_parser'

module VectorGenerate
  module DataLoaders
    module DocsLoader
    	extend self

    	def load!(dir)
    		Dir.
          glob("#{dir}/**/*.md").
          collect { |path| parse_file!(dir, path) }.
          sort_by { |hash| [ hash.fetch("id") ] }
    	end

    	private
    		def parse_file!(dir, path)
    			parsed = FrontMatterParser::Parser.parse_file(path)
      		front_matter = parsed.front_matter
      		id = path.sub(dir + "/", "").sub(/\.md$/, "")
    			permalink = "#{DOCS_PATH}/#{id}/"

      		front_matter.clone.merge({
      			"id" => id,
      			"permalink" => permalink
      		})#.validate_schema!(dir)
    		end
    end
  end
end