class Upright::Current < ActiveSupport::CurrentAttributes
  attribute :user
  attribute :subdomain
  attribute :site
  attribute :maintenance_service_codes

  def site
    super || Upright.current_site
  end
end
