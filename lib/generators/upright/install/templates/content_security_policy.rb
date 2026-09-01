# Be sure to restart your server when you modify this file.

# Content Security Policy tuned for Upright. Uncomment the block below to
# enforce it. Every source the engine actually uses is listed explicitly:
#
#   * JavaScript dependencies (Turbo, Stimulus, Leaflet, Frappe Charts) are
#     pinned to https://cdn.jsdelivr.net in the engine's config/importmap.rb.
#   * The Leaflet stylesheet is loaded from https://unpkg.com in the engine
#     layout; Turbo injects an inline <style> for its progress bar, which is
#     why style-src keeps :unsafe_inline (styles only — scripts stay strict).
#   * Map tiles come from OpenStreetMap (light) and Carto (dark); Leaflet's
#     default marker icons load from unpkg alongside its stylesheet.
#   * The inline <script type="importmap"> tag is authorized by a per-session
#     nonce via csp_meta_tag, which the engine layouts already render.
#
# To verify without breaking anything, start with
# config.content_security_policy_report_only = true and watch the browser
# console before enforcing.

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src     :self
#     policy.font_src        :self, :data
#     policy.img_src         :self, :data, "https://unpkg.com",
#                            "https://*.tile.openstreetmap.org"
#     policy.object_src      :none
#     policy.script_src      :self, "https://cdn.jsdelivr.net"
#     policy.style_src       :self, :unsafe_inline, "https://unpkg.com"
#     policy.connect_src     :self
#     policy.frame_ancestors :self
#     policy.base_uri        :self
#     # Specify URI for violation reports
#     # policy.report_uri "/csp-violation-report-endpoint"
#   end
#
#   # Generate session nonces for the inline importmap script tag.
#   config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
#   config.content_security_policy_nonce_directives = %w(script-src)
#
#   # Report violations without enforcing the policy.
#   # config.content_security_policy_report_only = true
# end
