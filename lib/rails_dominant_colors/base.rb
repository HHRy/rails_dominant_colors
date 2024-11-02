# frozen_string_literal: true

require 'mini_magick'

module RailsDominantColors
  class Base
    InvalidBase64 = Class.new(StandardError)
    FileNotFound = Class.new(StandardError)
    UrlNotFound = Class.new(StandardError)
    InvalidUrl = Class.new(StandardError)
    NotAnImage = Class.new(StandardError)
    EmptySource = Class.new(StandardError)

    attr_reader(:source, :colors)

    def initialize(source, colors)
      @source = source
      @colors = colors
    end

    def to_hex_alpha
      @to_hex_alpha ||= sort_by_size.map { |x| x[:hex] }
    end

    def to_hex
      @to_hex ||= sort_by_size.map { |x| x[:hex][0..6] }
    end

    def to_rgb_alpha
      @to_rgb_alpha ||= sort_by_size.map { |x| [x[:r], x[:g], x[:b], x[:a]] }
    end

    def to_rgb
      @to_rgb ||= sort_by_size.map { |x| [x[:r], x[:g], x[:b]] }
    end

    def to_hsl_alpha
      @to_hsl_alpha ||= sort_by_size.map do |x|
        rgb_to_hsl(
          x[:r] / 255.0,
          x[:g] / 255.0,
          x[:b] / 255.0,
          x[:a]
        )
      end
    end

    def to_hsl
      @to_hsl ||= sort_by_size.map do |x|
        rgb_to_hsl(
          x[:r] / 255.0,
          x[:g] / 255.0,
          x[:b] / 255.0
        )
      end
    end

    def to_pct
      @to_pct ||= sort_by_size.map { |x| ((x[:size].to_f / total) * 100).round(2) }
    end

    private

    def extensions
      @extensions ||= {
        'image/png': '.png',
        'image/jpeg': '.jpeg',
        'image/jpg': '.jpg',
        'image/gif': '.gif',
        'image/bmp': '.bmp',
        'image/webp': '.webp',
        'image/tiff': '.tif',
        'image/svg+xml': '.svg',
        'image/svg': '.svg'
      }
    end

    def image
      @image ||= ::MiniMagick::Image.open(source)
    end

    def execute
      @execute ||= MiniMagick.convert do |convert|
        convert << image.path
        convert << '-format' << '%c'
        convert << '-colors' << colors.to_s
        convert << '-depth' << '8'
        convert << '-alpha' << 'on'
        convert << 'histogram:info:'
      end
    end

    def sort_by_size
      @sort_by_size ||= parse.sort_by { |x| x[:size] }.reverse
    end

    def total
      @total ||= sort_by_size.map { |x| x[:size] }.reduce(:+)
    end

    def parse
      @parse ||= execute.split("\n").map { |l| l.gsub(%r{\s}, '') }.map do |l|
        match = l.match(
          %r{(?<size>[0-9]+):\((?<r>[0-9]+),(?<g>[0-9]+),(?<b>[0-9]+)[,]*(?<a>[0-9]+)\)(?<hex>#[0-9A-F]+)}
        )
        format_color(match)
      end
    end

    def format_color(color)
      {
        size: color[:size].to_i,
        r: color[:r].to_i,
        g: color[:g].to_i,
        b: color[:b].to_i,
        a: (color[:a].to_f / 255).round(2),
        hex: color[:hex]
      }
    end

    def rgb_to_hsl(r, g, b, a = nil)
      min, max = min_max(r, g, b)

      l = (max + min) / 2.0

      if max == min
        s = h = 0
      else
        d = max - min
        s = l >= 0.5 ? d / (2.0 - max - min) : d / (max + min)
        h = case max
            when r then (g - b) / d + (g < b ? 6.0 : 0)
            when g then (b - r) / d + 2.0
            when b then (r - g) / d + 4.0
            end
        h /= 6.0
      end

      format_hsl(h, s, l, a)
    end

    def min_max(r, g, b)
      max = [r, g, b].max
      min = [r, g, b].min
      [min, max]
    end

    def format_hsl(h, s, l, a)
      [(h * 360).round, (s * 100).round, (l * 100).round, a].compact
    end
  end
end
