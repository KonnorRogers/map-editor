require "app/features/design_system/static_palette.rb"

class ::Integer
  def to_sym
    self.to_s.to_sym
  end
end

module DesignSystem
  class SemanticPalette
    attr_accessor :colors

    def initialize(static_colors = DesignSystem::StaticPalette.new.colors)
      @colors = {
        black: static_colors.black,
        white: static_colors.white,
        surface: {
          raised: static_colors.white,
          default: static_colors.white,
          lowered: static_colors.dig(:gray, 95.to_sym),
          border: static_colors.dig(:gray, 90.to_sym)
        },
        #Text colors are used for standard text elements.
        #Recommended: minimum 4.5:1 contrast ratio between text colors and surface colors. */
        text: {
          normal: static_colors.dig(:gray, 10.to_sym),
          quiet: static_colors.dig(:gray, 40.to_sym),
          link: static_colors.dig(:blue, 40.to_sym),
        },
        # Overlays provide a backdrop for isolated content, often allowing background context to show through.
        # overlay: {
        #   modal: color-mix(in oklab, var(--wa-color-gray-05) 50%, transparent),
        #   inline: color-mix(in oklab, var(--wa-color-gray-80) 20%, transparent),
        # },
        # Shadows indicate elevation. Shadow color is used in your theme's shadow properties.
        # By default, the opacity of your shadow color is tied to the blur of shadows in your theme.
        # Because solid shadows appear stronger in color than diffused shadows, this helps keep consistent color intensity. */
        # shadow: color-mix(
        #   in oklab,
        #   var(--wa-color-gray-05) calc(var(--wa-shadow-blur-scale) * 4% + 8%),
      # transparent);

    # Focus color provides the default color of the focus ring for predictable keyboard navigation.
    # Recommended: minimum 3:1 contrast ratio against surfaces and background colors. */
        focus: static_colors.dig(:blue, 60.to_sym),
    # Hover and active colors are intended to be used in color-mix() to achieve consistent effects across components.
    # --wa-color-mix-hover: black 10%;
    # --wa-color-mix-active: black 20%;

    #
    # Semantic Colors
    # Five semantic groups - brand, success, neutral, warning, and danger - reinforce a component's message, intended usage, or expected results.
    # Within these groups, each color specifies a role -
    #  *  Fill for background colors or areas larger than a few pixels
    #  *  Border for borders, dividers, and other stroke-like elements
    #  *  On for content displayed on a fill with the corresponding attention
    # Each role has three options for attention - quiet, normal, and loud - where quiet draws the least attention and loud draws the most.
    #
        brand: {
          fill: {
            quiet: static_colors.dig(:blue, 95.to_sym),
            normal: static_colors.dig(:blue, 90.to_sym),
            loud: static_colors.dig(:blue, 50.to_sym),
          },
          border: {
            quiet: static_colors.dig(:blue, 90.to_sym),
            normal: static_colors.dig(:blue, 80.to_sym),
            loud: static_colors.dig(:blue, 60.to_sym),
          },
          on: {
            quiet: static_colors.dig(:blue, 40.to_sym),
            normal: static_colors.dig(:blue, 30.to_sym),
            loud: static_colors.white,
          }
        },
        success: {
          fill: {
            quiet: static_colors.dig(:green, 95.to_sym),
            normal: static_colors.dig(:green, 90.to_sym),
            loud: static_colors.dig(:green, 50.to_sym),
          },
          border: {
            quiet: static_colors.dig(:green, 90.to_sym),
            normal: static_colors.dig(:green, 80.to_sym),
            loud: static_colors.dig(:green, 60.to_sym),
          },
          on: {
            quiet: static_colors.dig(:green, 40.to_sym),
            normal: static_colors.dig(:green, 30.to_sym),
            loud: static_colors.white,
          },
        },
        warning: {
          fill: {
            quiet: static_colors.dig(:yellow, 95.to_sym),
            normal: static_colors.dig(:yellow, 90.to_sym),
            loud: static_colors.dig(:yellow, 50.to_sym),
          },
          border: {
            quiet: static_colors.dig(:yellow, 90.to_sym),
            normal: static_colors.dig(:yellow, 80.to_sym),
            loud: static_colors.dig(:yellow, 60.to_sym),
          },
          on: {
            quiet: static_colors.dig(:yellow, 40.to_sym),
            normal: static_colors.dig(:yellow, 30.to_sym),
            loud: static_colors.white,
          },
        },
        danger: {
          fill: {
            quiet: static_colors.dig(:red, 95.to_sym),
            normal: static_colors.dig(:red, 90.to_sym),
            loud: static_colors.dig(:red, 50.to_sym),
          },
          border: {
            quiet: static_colors.dig(:red, 90.to_sym),
            normal: static_colors.dig(:red, 80.to_sym),
            loud: static_colors.dig(:red, 60.to_sym),
          },
          on: {
            quiet: static_colors.dig(:red, 40.to_sym),
            normal: static_colors.dig(:red, 30.to_sym),
            loud: static_colors.white,
          }
        },
        neutral: {
          fill: {
            quiet: static_colors.dig(:gray, 95.to_sym),
            normal: static_colors.dig(:gray, 90.to_sym),
            loud: static_colors.dig(:gray, 20.to_sym),
          },
          border: {
            quiet: static_colors.dig(:gray, 90.to_sym),
            normal: static_colors.dig(:gray, 80.to_sym),
            loud: static_colors.dig(:gray, 60.to_sym),
          },
          on: {
            quiet: static_colors.dig(:gray, 40.to_sym),
            normal: static_colors.dig(:gray, 30.to_sym),
            loud: static_colors.white,
          }
        }
      }
    end
  end
end
