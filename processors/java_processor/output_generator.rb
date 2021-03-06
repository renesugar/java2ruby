module Java2Ruby
  class JavaProcessor
    module OutputGenerator
      attr_reader :converter, :comment_lines
      
      def initialize(converter)
        @converter = converter
        @comment_lines = []
        if converter && converter.current_generator
          @generator_comments = converter.current_generator.comment_lines.dup
          converter.current_generator.comment_lines.clear
        else
          @generator_comments = []
        end
        @output_lines = []
      end
      
      def in_context(&block)
        raise if @converter.current_generator == self
        last_generator = @converter.current_generator
        @converter.current_generator = self
        result = block.call
        @converter.current_generator = last_generator
        result
      end
      
      def output_parts
        @comment_lines.concat @generator_comments
        in_context do
          write_output
        end
        [@output_lines]
      end
            
      def comment(text, same_line)
        if same_line and not @output_lines.empty? and @output_lines.last[:type] == :output_line
          @output_lines.last[:content] << " ##{text}"
        else
          @comment_lines << text
        end
      end
      
      def write_comments
        @output_lines.concat(@comment_lines.map { |comment| { type: :output_line, content: "##{comment}" } })
        @comment_lines.clear
      end
      
      def puts_output(*parts)
        write_comments
        puts_output_without_comments(*parts)
      end
      
      def puts_output_without_comments(*parts)
        lines = []
        combine_output_parts parts, lines
        # lines.each { |line| raise line.inspect if not line.is_a?(Hash) or not (line[:type] == :output_line or line[:type] == :output_block) }
        @output_lines.concat lines
      end
      
      def combine_output_parts(parts, lines)
        parts.each do |part|
          case part
          when String, JavaType
            lines << { type: :output_line, content: "" } if lines.empty?
            lines.last[:content] << part.to_s
          when Array
            unless part.empty?
              lines.last[:content] << part.shift[:content] unless lines.empty?
              lines.concat part
            end
          when nil
            raise ArgumentError, parts.inspect
          when Hash
            raise ArgumentError, part.inspect 
          else
            combine_output_parts part.output_parts, lines
          end
        end
      end
      
      def indent_output
        outer_array = @output_lines
        @output_lines = []
        yield
        write_comments
        outer_array << { type: :output_block, children: @output_lines }
        @output_lines = outer_array
      end
      
      def lower_name(name)
        RubyNaming.lower_name name
      end
      
      def upper_name(name)
        new_word = false
        name.gsub(/./) { |char|
          case char
          when /[a-z]/
            new_word = true
            char.upcase
          when /[A-Z]/
            if new_word
              new_word = false
              "_" + char
            else
              char
            end
          else
            new_word = false
            char
          end
        }
      end
      
      def ruby_field_name(name)
        @converter.ruby_field_name name
      end
      
      def ruby_method_name(name, call = true)
        @converter.ruby_method_name name, call
      end  
    end
  end
end