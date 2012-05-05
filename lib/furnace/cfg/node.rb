module Furnace::CFG
  class Node
    attr_reader   :cfg, :label

    attr_accessor :target_labels, :exception_label
    attr_accessor :instructions, :control_transfer_instruction

    alias :insns  :instructions
    alias :insns= :instructions=
    alias :cti    :control_transfer_instruction
    alias :cti=   :control_transfer_instruction=

    def initialize(cfg, label=nil, insns=[], cti=nil,
            target_labels=[], exception_label=nil)
      @cfg, @label  = cfg, label

      @instructions = insns
      @control_transfer_instruction = cti

      @target_labels   = target_labels
      @exception_label = exception_label
    end

    def target_labels
      @target_labels
    end

    def targets
      @target_labels.map do |label|
        @cfg.find_node label
      end.freeze
    end

    def source_labels
      sources.map &:label
    end

    def sources
      @cfg.sources_for(self)
    end

    def exception
      @cfg.find_node @exception_label if @exception_label
    end

    def exits?
      targets == [@cfg.exit]
    end

    def ==(other)
      other.is_a?(Node) && self.label == other.label
    end

    def inspect
      if @label && @instructions
        "<#{@label}:#{@instructions.join ", "}>"
      elsif @label
        "<#{@label}>"
      elsif @insns
        "<!unlabeled>"
      else
        "<!exit>"
      end
    end
  end
end