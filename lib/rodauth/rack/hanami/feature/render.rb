# frozen_string_literal: true

module Rodauth
  module Rack
    module Hanami
      module Feature
        module Render
          def self.included(base)
            base.auth_methods :hanami_render
          end

          # Renders templates with layout. First tries to render a user-defined
          # template, otherwise falls back to Rodauth's template.
          def view(page, title)
            set_title(title)
            hanami_render(template: page.tr("-", "_"), layout: true) ||
              hanami_render(html: super, layout: true)
          end

          # Renders templates without layout. First tries to render a user-defined
          # template or partial, otherwise falls back to Rodauth's template.
          def render(page)
            hanami_render(partial: page.tr("-", "_"), layout: false) ||
              hanami_render(template: page.tr("-", "_"), layout: false) ||
              super
          end

          def button(*)
            super
          end

          private

          # Calls the Hanami renderer, returning nil if a template is missing.
          def hanami_render(template: nil, partial: nil, html: nil, layout: false)
            return html if html

            # Try to render using Hanami::View if available
            if defined?(::Hanami::View)
              view_path = template || partial
              return nil unless view_path

              begin
                # Hanami view rendering logic
                # This is a placeholder - actual implementation depends on
                # Hanami::View configuration in the app
                view_class = find_hanami_view(view_path)
                return nil unless view_class

                view_instance = view_class.new
                view_instance.call
              rescue ::Hanami::View::MissingTemplateError
                nil
              end
            end

            nil
          end

          def find_hanami_view(view_path)
            # Try to find the view class from Hanami app
            # This needs to be customizable per-app
            view_name = view_path.camelize
            "Rodauth::Views::#{view_name}".safe_constantize
          rescue
            nil
          end

          def set_title(title)
            return unless title_instance_variable

            hanami_action_instance.instance_variable_set(title_instance_variable, title)
          end
        end
      end
    end
  end
end
