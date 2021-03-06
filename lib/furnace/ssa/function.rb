module Furnace
  class SSA::Function
    attr_reader   :original_name
    attr_reader   :name
    attr_reader   :arguments
    attr_reader   :return_type

    attr_accessor :entry

    def initialize(name=nil, arguments=[], return_type=Type::Bottom.new)
      @original_name   = name
      @name            = name
      @return_type     = return_type.to_type
      @arguments       = arguments

      @basic_blocks    = Set.new

      @name_prefixes   = [""].to_set
      @next_name       = 0

      SSA.instrument(self)
    end

    def initialize_copy(original)
      @name_prefixes = [""].to_set
      @name          = @original_name

      value_map = Hash.new do |value_map, value|
        new_value = value.dup
        value_map[value] = new_value

        if new_value.is_a? SSA::User
          new_value.operands = value.translate_operands(value_map)
        end

        new_value
      end

      self.arguments = @arguments.map do |arg|
        new_arg = arg.dup
        new_arg.function = self
        value_map[arg] = new_arg

        new_arg
      end

      old_basic_blocks = @basic_blocks
      @basic_blocks    = Set[]

      old_basic_blocks.each do |bb|
        new_bb = bb.dup
        new_bb.function = self

        value_map[bb] = new_bb

        add new_bb
      end

      @entry = value_map[@entry]

      original.each do |bb|
        new_bb = value_map[bb]

        bb.each do |insn|
          new_insn = value_map[insn]
          new_insn.basic_block = new_bb
          new_bb.append new_insn
        end
      end
    end

    def name=(name)
      @name = name

      SSA.instrument(self)
    end

    def arguments=(arguments)
      @arguments = sanitize_arguments(arguments)

      @arguments.each do |arg|
        arg.function = self
      end

      SSA.instrument(self)
    end

    def return_type=(return_type)
      @return_type = return_type.to_type

      SSA.instrument(self)
    end

    def make_name(prefix=nil)
      if prefix.nil?
        (@next_name += 1).to_s
      else
        prefix = prefix.to_s

        if @name_prefixes.include? prefix
          "#{prefix}.#{@next_name += 1}"
        else
          @name_prefixes.add prefix
          prefix
        end
      end
    end

    def each(&proc)
      @basic_blocks.each(&proc)
    end

    alias each_basic_block each

    def size
      @basic_blocks.count
    end

    def include?(name)
      @basic_blocks.any? { |n| n.name == name }
    end

    def find(name)
      if block = @basic_blocks.find { |n| n.name == name }
        block
      else
        raise ArgumentError, "Cannot find basic block #{name}"
      end
    end

    def add(block)
      block.function = self
      @basic_blocks.add block

      SSA.instrument(self)
    end

    alias << add

    def remove(block)
      @basic_blocks.delete block
      block.detach

      SSA.instrument(self)
    end

    def each_instruction(*types, &proc)
      return to_enum(:each_instruction, *types) if proc.nil?

      each do |block|
        block.each(*types, &proc)
      end
    end

    def replace_type_with(type, replacement)
      @arguments.each do |arg|
        arg.replace_type_with(type, replacement)
      end

      each_instruction do |insn|
        insn.replace_type_with(type, replacement)
      end

      self.return_type = return_type.replace_type_with(type, replacement)

      self
    end

    def predecessors_for(name)
      predecessors = Set[]

      each do |block|
        if block.successor_names.include? name
          predecessors << block
        end
      end

      predecessors
    end

    def self.to_type
      SSA::FunctionType.new
    end

    def to_value
      SSA::Constant.new(self.class.to_type, @name)
    end

    def awesome_print(p=AwesomePrinter.new)
      p.keyword('function').
        nest(@return_type).
        text(@name).
        collection('(', ', ', ') {', @arguments).
        newline.
        collection(@basic_blocks).
        append('}').
        newline
    end

    alias inspect awesome_print

    protected

    def sanitize_arguments(arguments)
      arguments.each_with_index do |argument, index|
        if !argument.is_a?(SSA::Argument)
          raise ArgumentError, "function #{@name} arguments: #{argument.inspect} (at #{index}) is not an Argument"
        end
      end.dup.freeze
    end
  end
end
