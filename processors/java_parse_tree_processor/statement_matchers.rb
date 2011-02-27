module Java2Ruby
  class JavaParseTreeProcessor
    def match_block
      match :block do
        match "{"
        match_block_statements
        match "}"
      end
    end
    
    def match_block_statements
      loop_match :blockStatement do
        match_block_statement_children
      end
    end
    
    def match_block_statement_children
      if try_match :localVariableDeclarationStatement do
          match_localVariableDeclaration
          match ";"
        end
      elsif next_is? :classOrInterfaceDeclaration
        match_classOrInterfaceDeclaration
      else
        match_statement
      end
    end
    
    def match_statement
      match :statement do
        if try_match :statementExpression do
            expression = match_expression
            create_element :expression, :value => expression
          end
          match ";"
        elsif try_match "if"
          create_element :if do
            set_attribute :condition, match_parExpression
            create_element :true_statement do
              match_statement
            end
            if try_match "else"
              create_element :false_statement do
                match_statement
              end
            end
          end
        elsif try_match "switch"
          create_element :case do
            set_attribute :value, match_parExpression

            match "{"
            match :switchBlockStatementGroups do
              loop_match :switchBlockStatementGroup do
                create_element :case_branch do
                  values = []
                  loop_match :switchLabel do
                    if try_match "case"
                      match :constantExpression do
                         values << match_expression
                      end
                    else
                      match "default"
                      values = :default
                    end
                    match ":"
                  end
                  set_attribute :values, values
                  
                  loop_match(:blockStatement) do
                    match_block_statement_children
                  end
                end
              end
            end
            match "}"
          end
        elsif try_match "while"
          create_element :while do
            set_attribute :condition, match_parExpression
            match_statement
          end
        elsif try_match "do"
          create_element :do_while do
            match_statement
            match "while"
            set_attribute :condition, match_parExpression
            match ";"
          end
        elsif try_match "for"
          create_element :for do
            match "("
            match :forControl do
              if try_match :enhancedForControl do
                  set_attribute :type, :for_each
                  match_variableModifiers
                  set_attribute :entry_type, match_type
                  set_attribute :variable, match_name
                  match ":"
                  set_attribute :iterable, match_expression
                end
              else
                create_element :for_init do
	                try_match :forInit do
                    if next_is? :localVariableDeclaration
                      match_localVariableDeclaration
                    else
                      match_expression_list
                    end
                  end
                end
                match ";"
                if next_is? :expression
                  set_attribute :condition, match_expression
                end
                match ";"
                create_element :for_update do
	                try_match :forUpdate do
                    match_expression_list
                  end
                end
              end
            end
            match ")"
            create_element :for_child_statement do
              match_statement
            end
          end
        elsif try_match "try"
          try_children = []
          try_body_children = []
          match_block try_children
          try_children << { :type => :try_body, :children => try_body_children }
          try_match :catches do
            loop_match :catchClause do
              exception_type, exception_variable = nil
              match "catch"
              match "("
              match :formalParameter do
                match_variableModifiers
                exception_type = match_type
                match :variableDeclaratorId do
                  exception_variable = match_name
                end
              end
              match ")"
              catch_children = []
              match_block catch_children
              try_children << { :type => :rescue, :exception_type => exception_type, :exception_variable => exception_variable, :children => catch_children }
            end
          end
          if try_match "finally"
            finally_children = []
            match_block finally_children
            try_children << { :type => :ensure, :children => try_body_children }
          end
          create_element :try, :children => try_children
        elsif try_match "break"
          if try_match ";"
            create_element :break
          else
            name = match_name
            match ";"
            create_element :break, :name => name
          end
        elsif try_match :disabled_break
          match ";"
        elsif try_match "continue"
          if try_match ";"
            create_element :continue
          else
            name = match_name
            match ";"
            create_element :continue, :name => name
          end
        elsif try_match "return"
          expression = next_is?(:expression) ? match_expression : nil
          create_element :return, :value => expression
          match ";"
        elsif try_match "throw"
          throw_expression = match_expression
          match ";"
          create_element :raise, :exception => throw_expression
        elsif try_match "synchronized"
          puts_output "synchronized(", match_parExpression, ") do"
          indent_output do
            match_block
          end
          puts_output "end"
        elsif try_match "assert"
          assert_line = ["raise AssertError"]
          assert_expression = match_expression
          if try_match ":"
            assert_line.push ", ", match_expression.typecast(JavaType::STRING)
          end
          match ";"
          assert_line.push " if not (", assert_expression, ")"
          puts_output(*assert_line)
        elsif next_is? :block
          children = []
          create_element :block do
            match_block
          end
        elsif try_match ";"
          # nothing
        else
          create_element :label do
            set_attribute :name, match_name
            match ":"
            match_statement
          end
        end
      end
    end
    
    def handle_case_end(element)
      case element[:internal_name]
      when :block
        handle_case_end element[:children][-2]
      when :blockStatement
        handle_case_end element[:children].first
      when :statement
        case element[:children].first[:internal_name]
        when "break"
          element[:children].first[:internal_name] = :disabled_break if element[:children][1][:internal_name] == ";"
          true
        when "return", "throw"
          true
        when "if"
          handle_case_end(element[:children][2]) && (element[:children].size < 5 || handle_case_end(element[:children][4]))
        when :block
          handle_case_end element[:children].first
        else
          false
        end
      else
        false
      end
    end
    
  end
end
