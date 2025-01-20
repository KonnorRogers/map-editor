require "app/features/design_system/color.rb"

module DesignSystem
  class StaticPalette
    attr_accessor :colors

    def initialize
=begin
    Literal Colors
    Each color is identified by a number that corresponds to its perceived lightness, where 100 is equal to white and 0 is equal to black.
    Each lightness value has nearly uniform WCAG 2.1 contrast across hues.
    A difference of 40 between lightness values ensures a minimum 3:1 contrast ratio.
    A difference of 50 between lightness values ensures a minimum 4.5:1 contrast ratio.
    A difference of 60 between lightness values ensures a minimum 7:1 contrast ratio.
=end
      @colors = {
        white: "#ffffff",
        black: "#000000",
        red: {
          "95": "#ffefef",
          "90": "#ffdddc",
          "80": "#ffb7b6",
          "70": "#fc9090",
          "60": "#f2676c",
          "50": "#de2d44",
          "40": "#b11036",
          "30": "#861a2f",
          "20": "#641122",
          "10": "#400712",
          "05": "#2a030a",
        },
        yellow: {
          "95": "#fdf3ba",
          "90": "#fee590",
          "80": "#fcc041",
          "70": "#f39b00",
          "60": "#e07b00",
          "50": "#bb5a00",
          "40": "#924200",
          "30": "#743200",
          "20": "#572300",
          "10": "#361300",
          "05": "#240b00",
        },
        green: {
          "95": "#e2f9e2",
          "90": "#c2f2c1",
          "80": "#92da97",
          "70": "#5dc36f",
          "60": "#00ac49",
          "50": "#008825",
          "40": "#006800",
          "30": "#005300",
          "20": "#003c00",
          "10": "#002400",
          "05": "#001700",
        },
        teal: {
          "95": "#e3f7f5",
          "90": "#c6eeeb",
          "80": "#81d9d3",
          "70": "#34c2b9",
          "60": "#10a69d",
          "50": "#00837c",
          "40": "#00645e",
          "30": "#004e49",
          "20": "#003935",
          "10": "#002220",
          "05": "#001513",
        },
        blue: {
          "95": "#ebf4ff",
          "90": "#d4e7ff",
          "80": "#a6ccff",
          "70": "#77b1ff",
          "60": "#4895fd",
          "50": "#0070ef",
          "40": "#0055b8",
          "30": "#004390",
          "20": "#00306c",
          "10": "#001c45",
          "05": "#00112f",
        },
        indigo: {
          "95": "#f0f2fe",
          "90": "#e2e4fc",
          "80": "#c2c6f8",
          "70": "#a5a9f2",
          "60": "#8a8beb",
          "50": "#6b65e2",
          "40": "#5246c1",
          "30": "#412eaa",
          "20": "#321393",
          "10": "#1c006a",
          "05": "#130049",
        },
        violet: {
          "95": "#f9effd",
          "90": "#f4defb",
          "80": "#e7baf7",
          "70": "#d996ef",
          "60": "#c674e1",
          "50": "#a94dc6",
          "40": "#8732a1",
          "30": "#6d2283",
          "20": "#521564",
          "10": "#330940",
          "05": "#22042b",
        },
        gray: {
          "95": "#f1f2f3",
          "90": "#e4e5e9",
          "80": "#c7c9d0",
          "70": "#abaeb9",
          "60": "#9194a2",
          "50": "#717584",
          "40": "#545868",
          "30": "#424554",
          "20": "#2f323f",
          "10": "#1b1d26",
          "05": "#101219",
        },
      }

      @colors.transform_values! do |str_or_hash|
        if str_or_hash.is_a?(String)
          str = str_or_hash
          DesignSystem::Color.hex_to_rgba(str)
        elsif str_or_hash.is_a?(Hash)
          hash = str_or_hash
          hash.transform_values! { |hex_code| DesignSystem::Color.hex_to_rgba(hex_code) }
        end
      end
    end
  end
end
