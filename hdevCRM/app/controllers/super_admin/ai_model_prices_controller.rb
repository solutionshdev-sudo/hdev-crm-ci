class SuperAdmin::AiModelPricesController < SuperAdmin::ApplicationController
  # Sem edit/update/destroy: preço se troca criando linha nova; o supersede
  # do vigente anterior acontece no after_create do AiModelPrice.
end
