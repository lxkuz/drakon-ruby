# frozen_string_literal: true

module DrakonRuby
  # Общий префикс файла и обёртка `.call` для сгенерированных классов.
  module ServiceObject
    FILE_PREFIX = "# frozen_string_literal: true\n\nrequire \"ostruct\"\n\n"

    module_function

    # Текст `def self.call ... new.<entry>(ctx)`; base_indent — один уровень отступа класса (обычно два пробела).
    def class_call_method(entry_method_name, base_indent)
      mn = entry_method_name.to_s
      inner = base_indent * 2
      "#{base_indent}def self.call(ctx = nil, **kwargs)\n" \
        "#{inner}ctx ||= OpenStruct.new(**kwargs)\n" \
        "#{inner}new.#{mn}(ctx)\n" \
        "#{base_indent}end\n\n"
    end
  end
end
