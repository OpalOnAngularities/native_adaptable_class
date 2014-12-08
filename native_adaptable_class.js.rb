''||eval('begin=undefined');_=nil
=begin
;eval(Opal.compile('=begin\n'+heredoc(function(){/*
=end

require 'native'
require 'native_object_writer'

module NativeAdaptableClass

  module InstanceMethods

    def to_n
      @_native_adapter ||= self.class.new_adapter_for(self)
    end

  end

  def self.extended(klass)
    klass.send(:include, InstanceMethods)
  end

  def native_class
    `Object.defineProperty(self, 'Adapter', {get: function(){ return #{`this`.native_adapter_class}; }})`
    super
  end

  def new_adapter_for(instance)
    adapter = `Object.create(#{native_adapter_class}.prototype)`
    `Object.defineProperty(#{adapter}, '$_opal_instance_$', {get: function() { return #{instance}; }})`
    adapter
  end

  def native_adapter_class
    @_native_class ||= begin
      func = NativeObjectWriter.function do |*args|
        opal_instance = `#@native.$_opal_class_$`.new(*args.map { |arg| Native(arg) })
        `Object.defineProperty(#@native, '$_opal_instance_$', {get: function() { return #{opal_instance}; }})`
        opal_instance.instance_variable_set(:@_native_adapter, `this`)
        self
      end
      NativeObjectWriter.modify(`func.prototype`, self) do |opal_class|
        `Object.defineProperty(#@native, '$_opal_class_$', {get: function() { return #{opal_class}; }})`
      end
      native_alias_map.each_spec do |native_name, spec|
        spec.write_to_object(`func.prototype`, native_name)
      end
      func
    end
  end

  def to_n
    native_adapter_class
  end

  def native_alias(native_name, name)
    native_method(name => native_name)
    super
  end

  def native_method(*names)
    each_aliasing_names(names) do |name, native_name, options|
      own_native_alias_map.add_method(name, native_name)
      own_native_alias_map.merge_options(native_name, options)
    end
  end

  def native_property(*names)
    each_aliasing_names(names) do |name, native_name, options|
      own_native_alias_map.add_getter(name, native_name)
      own_native_alias_map.add_setter("#{name}=", native_name)
      own_native_alias_map.merge_options(native_name, options)
    end
  end

  def native_property_readonly(*names)
    each_aliasing_names(names) do |name, native_name, options|
      own_native_alias_map.add_getter(name, native_name)
      own_native_alias_map.merge_options(native_name, options)
    end
  end

  def native_property_attr_reader(*names)
    attr_reader(each_aliasing_names(names).map do |name, native_name, options|
      own_native_alias_map.add_getter(name, native_name)
      own_native_alias_map.merge_options(native_name, options)
      name
    end)
  end

  def native_property_attr_writer(*names)
    attr_writer(each_aliasing_names(names).map do |name, native_name, options|
      own_native_alias_map.add_setter("#{name}=", native_name)
      own_native_alias_map.merge_options(native_name, options)
      name
    end)
  end

  def native_property_attr_accessor(*names)
    attr_accessor(each_aliasing_names(names).map do |name, native_name, options|
      own_native_alias_map.add_getter(name, native_name)
      own_native_alias_map.add_setter("#{name}=", native_name)
      own_native_alias_map.merge_options(native_name, options)
      name
    end)
  end

  def native_alias_map
    return own_native_alias_map if disable_automatic_native_method?
    auto_method_map = AliasMap.new
    (self.public_instance_methods(true) - ::Object.instance_methods(true)).select { |m| /[a-zA-Z_][a-zA-Z0-9_]+/ =~ m }.each do |m|
      auto_method_map.add_method(m, auto_native_name(m))
    end
    auto_method_map.merge(own_native_alias_map)
  end

  def disable_automatic_native_method!(v = true)
    @disable_automatic_native_method = v
  end

  def disable_automatic_native_method?
    @disable_automatic_native_method
  end

  private

  def own_native_alias_map
    @_own_native_alias_map ||= AliasMap.new
  end

  def each_aliasing_names(names)
    return to_enum(:each_aliasing_names, names) unless block_given?
    names.each do |name|
      options = {}
      name, options = name if name.is_a?(Array)
      case name
      when Hash
        name.each do |_name, native_name|
          native_name, options = native_name if native_name.is_a?(Array)
          yield _name, native_name, options
        end
      else
        yield name, auto_native_name(name), options
      end
    end
    nil
  end

  def auto_native_name(ruby_name)
    ruby_name = ruby_name[0..-2] if ruby_name[-1] == '='
    ruby_name.to_s.split('_').inject { |n, next_seg| n + next_seg.capitalize }.to_sym
  end

  class AliasMap

    def initialize
      @specs = {}
    end

    def native_names
      specs.keys
    end

    def delete_native_name(native_name)
      specs[native_name.to_sym]
    end

    def each_spec
      specs.each do |native_name, spec|
        yield native_name, spec
      end
    end

    def add_method(name, native_name)
      method_spec(native_name).name = name
    end

    def add_getter(name, native_name)
      property_spec(native_name).getter_name = name
    end

    def add_setter(name, native_name)
      property_spec(native_name).setter_name = name
    end

    def merge_options(native_name, options)
      specs[native_name.to_sym].options.merge!(options)
    end

    def merge(another_map)
      AliasMap.new.merge!(self).merge!(another_map)
    end

    def merge!(another_map)
      another_map.specs.each { |k,v| specs[k] = v.dup }
      self
    end

    protected

    attr_reader :specs

    private

    def property_spec(native_name)
      spec = specs[native_name.to_sym]
      spec = (specs[native_name.to_sym] = PropertySpec.new) if spec.nil? || !spec.property?
      spec
    end

    def method_spec(native_name)
      spec = specs[native_name.to_sym]
      spec = (specs[native_name.to_sym] = MethodSpec.new) if spec.nil? || !spec.method?
      spec
    end

    class AliasSpec

      def initialize(type)
        @type = type
      end

      def method?
        @type == :method
      end

      def property?
        @type == :property
      end

      def method_names
        raise 'abstract'
      end

      def write_to_object(obj, native_name)
        raise 'abstract'
      end

      def options
        @_options ||= {}
      end

      def no_conversion?
        !!options[:no_conversion]
      end

    end

    class MethodSpec < AliasSpec

      def initialize
        super(:method)
      end

      attr_accessor :name

      def method_names
        [name]
      end

      def write_to_object(obj, native_name)
        NativeObjectWriter.modify(obj, self, native_name) do |spec, native_name|
          fn = ->(*args){ `#@native.$_opal_instance_$`.send(spec.name, *args) }
          if spec.no_conversion?
            set_function(native_name, &fn)
          else
            set_function_with_conversion(native_name, &fn)
          end

        end
      end

    end

    class PropertySpec < AliasSpec

      def initialize
        super(:property)
      end

      attr_accessor :getter_name, :setter_name

      def accessor_names
        accessors = {}
        accessors[:get] = getter_name if getter_name
        accessors[:set] = setter_name if setter_name
        accessors
      end

      def method_names
        [getter_name, setter_name].compact
      end

      def write_to_object(obj, native_name)
        NativeObjectWriter.modify(obj, self, native_name) do |spec, native_name|
          accessors = {}
          spec.accessor_names.each do |type, name|
            fn = ->(*args) { `#@native.$_opal_instance_$`.send(name, *args) }
            if spec.no_conversion?
              accessors[type] = fn
            else
              accessors[type] = proc_with_conversion(&fn)
            end
          end
          property_with_accessor native_name, accessors unless accessors.empty?
        end
      end
    end

  end

end

module Kernel

  alias_method :_original_Native, :Native
  def Native(value)
    %x{
      if (typeof #{value} === 'object' && #{value}.$_opal_instance_$) {
        // value is an adapted instance
        return #{value}.$_opal_instance_$;
      } else if (typeof #{value} === 'function' && #{value}.prototype.$_opal_class_$) {
        // value is an adapter class
        return #{value}.prototype.$_opal_class_$;
      }
    }
    _original_Native(value)
  end

end

#*/})));