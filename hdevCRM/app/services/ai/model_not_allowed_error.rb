# Plano da conta não libera o modelo pedido (e nenhum fallback existe) ou a
# conexão está desativada. Herda de QuotaExceededError de propósito: pros
# call sites, "sem modelo liberado" e "sem tokens" têm o mesmo tratamento —
# a IA fica muda em vez de derrubar o fluxo.
class Ai::ModelNotAllowedError < Ai::QuotaExceededError; end
