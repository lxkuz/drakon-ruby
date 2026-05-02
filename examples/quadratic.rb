# frozen_string_literal: true

require "ostruct"

class Quadratic
  def self.call(ctx = nil, **kwargs)
    ctx ||= OpenStruct.new(**kwargs)
    new.call(ctx)
  end

  def call(ctx)
    ctx.a ||= 1
    ctx.b ||= -5
    ctx.c ||= 6
    if (ctx.a == 0)
      if (ctx.b == 0)
        if (ctx.c == 0)
          puts "любое действительное x (тождество 0 = 0)"
        else
          puts "нет решений (противоречие)"
        end
      else
        ctx.x = -ctx.c.to_f / ctx.b
        puts "линейное уравнение: x = #{ctx.x}"
      end
    else
      ctx.d = ctx.b * ctx.b - 4 * ctx.a * ctx.c
      if (ctx.d > 0)
        sd = Math.sqrt(ctx.d)
        ctx.x1 = (-ctx.b + sd) / (2.0 * ctx.a)
        ctx.x2 = (-ctx.b - sd) / (2.0 * ctx.a)
        puts "D > 0: два корня x1=#{ctx.x1}, x2=#{ctx.x2}"
      else
        if (ctx.d == 0)
          ctx.x = -ctx.b / (2.0 * ctx.a)
          puts "D = 0: один корень x=#{ctx.x}"
        else
          puts "нет действительных корней (D отрицательный)"
        end
      end
    end
  end
end
