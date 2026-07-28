class SuperAdmin::AgencyUsersController < SuperAdmin::ApplicationController
  # agency user rows link back to the user show page, mirroring account_users
  def show
    redirect_to super_admin_user_path(requested_resource.user)
  end

  def create
    resource = resource_class.new(resource_params)
    authorize_resource(resource)

    if resource.save
      redirect_back(fallback_location: [namespace, resource.agency], notice: translate_with_resource('create.success'))
    else
      redirect_back(fallback_location: [namespace, resource.agency], flash: { error: resource.errors.full_messages.first })
    end
  end

  def destroy
    if requested_resource.destroy
      flash[:notice] = translate_with_resource('destroy.success')
    else
      flash[:error] = requested_resource.errors.full_messages.join('<br/>')
    end
    redirect_back(fallback_location: [namespace, requested_resource.agency])
  end
end
