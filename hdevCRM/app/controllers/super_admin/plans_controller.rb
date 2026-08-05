class SuperAdmin::PlansController < SuperAdmin::ApplicationController
  # Ordem da vitrine (position) em vez do id do Administrate.
  def scoped_resource
    resource_class.ordered
  end
end
