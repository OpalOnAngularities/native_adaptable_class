'' || eval('begin = 0'); _ = nil
=begin
; eval(Opal.compile('=begin\n' + heredoc(function () {/*
=end

require 'native'

class NativeObjectWriter

  UNDEFINED = `void(0)`

  class << self

    def function(pass_ons = {}, &block)
      proc do |*args|
        Wrapper.new(`this`, pass_ons).instance_exec(*args, &block)
      end.to_n
    end

    def new_object(*pass_ons, &block)
      call_in_wrapper(`{}`, pass_ons, &block).to_n
    end

    def new
      raise Error, 'No new. Use new_object.'
    end

    def modify(obj, *pass_ons, &block)
      obj = obj.to_n rescue obj
      raise ArgumentError, 'non native object specified.' if !Kernel.native?(obj)
      call_in_wrapper(obj, pass_ons, &block).to_n
    end

    private

    def call_in_wrapper(obj, pass_ons, &block)
      native_obj = Wrapper.new(obj, pass_ons)
      native_obj.instance_exec(*pass_ons, &block)
      native_obj
    end

  end

  class Wrapper < Native::Object

    def initialize(obj, pass_ons = [])
      super(obj)
      @pass_ons = pass_ons
    end

    attr_reader :pass_ons

    def set_property(*args)
      case args.length
      when 1
        args[0].each { |name, value| set_property(name, value) }
      when 2
        name, value = args
        self[name] = Native.convert(value)
      else
        raise ArgumentError, "wrong number of arguments (#{args.length} for 1 or 2)"
      end
    end

    def set_function(name, &func)
      fn = proc do |*args|
        Wrapper.new(`this`).instance_exec(*args, &func)
      end
      set_property(name, fn)
    end

    def set_function_with_conversion(name, &func)
      set_function(name, &proc_with_conversion(&func))
    end

    def with_conversion(*args, &block)
      wrapped_args = args.map { |arg| Native(arg) }
      result = block.call(*wrapped_args)
      Native.convert(result)
    end

    def proc_with_conversion(&block)
      proc do |*args|
        with_conversion(*args) do |*args|
          self.instance_exec(*args, &block)
        end
      end
    end

    def define_property(name)
      descriptor = Wrapper.new(`{}`)
      yield descriptor if block_given?
      desc = Native.convert(descriptor)
      `Object.defineProperty(#@native, #{name}, #{desc})`
      nil
    end

    def property_with_accessor(*args)
      case args.length
      when 1
        args[0].each { |name, value| property_with_accessor(name, value) }
      when 2
        name, get_set = args
        raise ArgumentError if get_set.nil? || get_set.empty?
        define_property(name) do |descriptor|
          descriptor.set_property(enumerable: true,
                                  configurable: true)
          get_set.each do |accessor_type, func|
            raise ArgumentError unless [:get, :set].include?(accessor_type)
            descriptor.set_function(accessor_type, &func)
          end
        end
      else
        raise ArgumentError, "wrong number of arguments (#{args.length} for 1 or 2)"
      end
    end

    private

    # some methods from Kernel
    ::Object.new.tap do |kernel_delegatee|
      [:proc, :lambda].each do |m|
        define_method m, kernel_delegatee.method(m)
      end
    end

    # some methods from Kernel
    [:native?, :Native, :Array].each do |m|
      define_method(m) { |*args, &block| ::Object.new.send(m, *args, &block) }
    end

  end

end

#*/})));