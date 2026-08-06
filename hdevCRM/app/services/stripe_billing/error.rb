# Erro de negócio do billing: nasce com a mensagem já traduzida, pronta pra
# virar 422 nos controllers (rescue_from em cada escopo).
class StripeBilling::Error < StandardError
  def initialize(i18n_key)
    super(I18n.t("errors.subscriptions.#{i18n_key}"))
  end
end
