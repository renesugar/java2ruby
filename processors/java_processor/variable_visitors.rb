module Java2Ruby
  class JavaProcessor
    def visit_variable_declaration(element, data)
      type = visit(element[:var_type])
      real_value = (element[:value] && visit(element[:value])) || type.default
      var_name = @statement_context.new_variable element[:name], type
      puts_output "#{var_name} = ", real_value
    end
    
    def visit_array_initializer(element, data)
      output_parts = [visit(element[:value_type]), ".new(["]
      element[:values].each_index do |i|
        output_parts << ", " if i > 0
        output_parts << visit(element[:values][i])
      end
      output_parts << "])"
      Expression.new :Array, *output_parts
    end
  end
end