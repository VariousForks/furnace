module Furnace
  class SSA::BasicBlock < SSA::NamedValue
    def initialize(insns=[], name=nil)
      @instructions = insns.to_a

      super(name)
    end

    def initialize_copy(original)
      @instructions = []

      super
    end

    def to_a
      @instructions.dup
    end

    def function=(function)
      if @function && @function != function
        @function.remove self
      end

      super
    end

    def include?(instruction)
      @instructions.include? instruction
    end

    def each(*types, &proc)
      if types.empty?
        @instructions.each(&proc)
      else
        return to_enum(:each, *types) if proc.nil?

        @instructions.each do |insn|
          if types.include?(insn.class)
            yield insn
          end
        end
      end
    end

    alias each_instruction each

    def prepend(instruction)
      instruction.basic_block = self
      @instructions.unshift instruction

      SSA.instrument(self)
    end

    def append(instruction)
      instruction.basic_block = self
      @instructions.push instruction

      SSA.instrument(self)
    end

    alias << append

    def index(instruction)
      @instructions.index(instruction)
    end

    def insert(before, instruction)
      unless (idx = index(before))
        raise ArgumentError, "Instruction #{before} is not found"
      end

      instruction.basic_block = self
      @instructions.insert idx, instruction

      SSA.instrument(self)
    end

    def remove(instruction)
      @instructions.delete instruction
      instruction.detach

      SSA.instrument(self)
    end

    def replace(instruction, replace_with)
      insert instruction, replace_with
      remove instruction
    end

    def splice(after)
      unless (idx = index(after))
        raise ArgumentError, "Instruction #{after} is not found"
      end

      result = []

      @instructions[idx + 1..-1].each do |insn|
        result << insn
        remove insn
      end

      result
    end

    def terminator
      @instructions.last
    end

    def successor_names
      terminator.successors
    end

    def successors
      successor_names.map do |label|
        @function.find(label)
      end
    end

    def predecessor_names
      predecessors.map(&:name)
    end

    def predecessors
      @function.predecessors_for(@name)
    end

    def exits?
      terminator.exits?
    end

    def self.to_type
      SSA::BasicBlockType.new
    end

    def type
      self.class.to_type
    end

    def constant?
      true
    end

    def awesome_print(p=AwesomePrinter.new)
      p.text(@name).
        append(":").
        newline

      p.collection(@instructions) do |insn|
        p.append('   ').
          nest(insn).
          newline
      end

      p.newline
    end

    def awesome_print_as_value(p=AwesomePrinter.new)
      p.keyword('label').
        name(name)
    end
  end
end
