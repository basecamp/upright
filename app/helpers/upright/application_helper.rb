module Upright::ApplicationHelper
  def current_or_default_site
    Upright::Current.site || Upright.sites.first
  end

  def site_name(site)
    "#{country_flag(site.country)} #{site.city}"
  end

  def metrics_subdomain
    if Upright::Current.site.nil? || metrics_sites.none?
      Upright.configuration.global_subdomain
    elsif Upright::Current.site.stores_metrics?
      Upright::Current.site.code
    end
  end

  def metrics_sites_sentence
    metrics_sites.map(&:city).to_sentence
  end

  def page_title_tag(app_name = "Upright")
    tag.title [ @page_title, app_name ].compact.join(" · ")
  end

  def upright_stylesheet_link_tag(**options)
    engine_stylesheets = Upright::Engine.root.join("app/assets/stylesheets/upright").glob("*.css")
      .map { |f| "upright/#{f.basename('.css')}" }.sort
    stylesheet_link_tag(*engine_stylesheets, *Upright.configuration.public_stylesheets, **options)
  end

  private

  def metrics_sites
    Upright.sites.select(&:stores_metrics?)
  end

  def country_flag(country_code)
    country_code&.upcase&.gsub(/[A-Z]/) { |c| (c.ord + 0x1F1A5).chr(Encoding::UTF_8) }
  end
end
