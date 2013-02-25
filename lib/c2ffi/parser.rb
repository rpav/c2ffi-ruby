module C2FFI
   private
  
  TYPE_TABLE = {
    ":unsigned-int" => ":uint",
    ":unsigned-char" => ":uchar",
    ":unsigned-long" => ":ulong",
    ":function-pointer" => ":pointer",
    
  }

   public

  class Parser
     private

    def add_struct(name)
      if(name[0] == "_")
        name = "C" + name
      elsif(name == "")
        name = sprintf("Anon_Type_%d", @anon_counter)
        @anon_counter += 1
        return name
      end

      name = name.capitalize.gsub!(/_([a-z])/) { |m| "_" + m[1].upcase } 
      @struct_type[name] = true
      return name
    end

    def add_enum(name)
      if(name == "")
        name = sprintf(":anon_type_%d", @anon_counter)
        @anon_counter += 1
        return name
      end

      if(name[0] != ":")
        return ":" + name
      else
        return name
      end
    end

    def make_struct(form)
      name = add_struct(form[:name])
      
      if form[:tag] == ":struct"
        type = "FFI::Struct"
      else
        type = "FFI::Union"
      end

      s = Array.new
      s << "class #{name} < #{type}"

      if(form[:fields].length > 0)
        s << "  layout \\"
        size = form[:fields].length
        sep = ","
        form[:fields].each_with_index {
          | f, i |
          sep = "" if i >= (size-1)
          s << sprintf("    :%s, %s%s", f[:name], parse_type(f[:type]), sep)
        }
      end
      s << "end"

      return s
    end
    
    def parse_type(form)
      tt = @type_table[form[:tag]]
      return tt if tt

      case(form[:tag])
      when ":pointer"
        pointee = parse_type(form[:type])
        if(pointee == ":char" || pointee == ":uchar")
          return ":string"
        elsif(@struct_type[pointee])
          return @struct_type[pointee] + ".ptr"
        else
          return ":pointer"
        end

      when ":array"
        return sprintf("[%s, %d]",
                       parse_type(form[:type]),
                       form[:size])

      when ":struct", ":union"
        return add_struct(form[:name])
      when ":enum"
        return add_enum(form[:name])
        
      when "enum"
        form[:name] = add_enum(form[:name])
        parse_toplevel(form)
        return form[:name]
      when "struct", "union"
        form[:name] = add_struct(form[:name])
        parse_toplevel(form)
        return form[:name]
      end

      # All non-Classy types are :-prefixed?
      if(form[:tag][0] != ":")
        return ":" + form[:tag]
      else 
        return form[:tag]
      end
    end

    def parse_toplevel(form)
      case form[:tag]
      when "typedef"
        type = parse_type(form[:type])

        # I don't think typedef works right with structs, so assign
        if(@struct_type[type])
          name = add_struct(form[:name])
          s = sprintf("%s = %s", name, type);
        else
          s = sprintf("typedef %s, :%s", type, form[:name])
        end
        
      when "const"
        type = parse_type(form[:type])
        s = sprintf(type == ":string" ? "%s = \"%s\"" : "%s = %s",
                    form[:name].upcase, form[:value])
      when "extern"
        s = sprintf("attach_variable :%s, :%s, %s",
                    form[:name], form[:name],
                    parse_type(form[:type]))
      when "function"
        s = Array.new
        s << sprintf("attach_function '%s', [", form[:name])
        form[:parameters].each {
          | f |
          s << "  " + parse_type(f[:type]) + ","
        }
        s << sprintf("], %s", parse_type(form["return-type".intern]))
        #                     emacs doesn't like :"foo" ---^
        
      when "struct", "union"
        name = add_struct(form[:name])
        s = make_struct(form)
      when "enum"
        name = add_enum(form[:name])
        s = Array.new
        s << sprintf("enum %s, [", name)
        form[:fields].each {
          | f |
          s << sprintf("  :%s, %s,",
                       f[:name], f[:value])
        }
        s << "]"
      end

      @toplevels << s if s
    end

     public

    def initialize()
      @type_table = TYPE_TABLE.dup
      @struct_type = Hash.new
      @toplevels = Array.new
      @anon_counter = 0
    end

    def parse(module_name, libs, arr, out = $stdout)
      arr.each {
        | form |
        parse_toplevel(form)
      }

      out.print "require 'ffi'\n\n"
      out.puts  "module #{module_name}"
      out.puts  "  extend FFI::Library"
      case libs
        when String
        out.puts "  ffi_lib \"#{libs}\""
        else
        out.printf "  ffi_lib %s\n", libs.map { |s| "\"#{s}\"" }.join(", ")
      end

      @toplevels.each { |t|
        out.puts
        case t
        when String
          out.printf("  %s\n", t)
        when Array
          t.each { |l|
            out.printf("  %s\n", l)
          }
        end
      }
      out.puts "end"
    end

    def Parser.parse(module_name, libs, arr, out = $stdout)
      parser = Parser.new
      parser.parse(module_name, libs, arr, out)
    end
  end
end
