class SuperAdmin::AgenciesController < SuperAdmin::ApplicationController
  def destroy_logo
    requested_resource.logo.purge
    redirect_back(fallback_location: super_admin_agencies_path)
  end

  def destroy_logo_dark
    requested_resource.logo_dark.purge
    redirect_back(fallback_location: super_admin_agencies_path)
  end

  def destroy_logo_thumbnail
    requested_resource.logo_thumbnail.purge
    redirect_back(fallback_location: super_admin_agencies_path)
  end

  def scoped_resource
    resource_class.with_attached_logo
  end
end
