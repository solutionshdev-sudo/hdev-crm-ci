# Salva nome e e-mail no cadastro do contato DESTA conversa.
#
# Mesmo espírito do Chatbots::Nodes::CollectNode#map_to_contact, com uma
# diferença deliberada: lá a falha de validação é engolida (o fluxo não pode
# travar), aqui ela volta como Ai::ToolError para o modelo corrigir — e-mail
# duplicado ou malformado é justamente o que ele consegue confirmar com o
# cliente na iteração seguinte.
#
# Escopo só do contexto injetado: o contato é o da conversa, nunca um id vindo
# do modelo (ver Ai::ToolRegistry).
#
# ponytail: nada aqui enfileira job dentro do `call`. O savepoint do dry-run
# desfaz banco, não fila — tool que dispare side-effect assíncrono precisa de
# outro desenho.
class Ai::Tools::AtualizarContato < Ai::Tool
  SCHEMA = {
    type: 'object',
    properties: {
      nome: { type: 'string', description: 'Nome do cliente, como ele mesmo informou.' },
      email: { type: 'string', description: 'E-mail do cliente, ex: "maria@empresa.com".' }
    }
  }.freeze

  declare(
    name: 'atualizar_contato',
    description: <<~DESC.squish,
      Salva no cadastro o nome e o e-mail do cliente desta conversa. Chame assim
      que ele informar um desses dados. Envie só os campos que ele realmente
      informou: campo omitido mantém o valor que já está no cadastro. Só altera
      o contato desta conversa.
    DESC
    schema: SCHEMA
  )

  def call(input)
    raise Ai::ToolError, 'Esta ferramenta só funciona dentro de uma conversa de atendimento.' if conversation.nil?

    contact = conversation.contact
    return 'Esta conversa não tem contato associado, não há cadastro para atualizar.' if contact.blank?

    attributes = attributes_from(input)
    return 'Nenhum dado informado. Envie nome e/ou email para atualizar o cadastro.' if attributes.empty?

    contact.assign_attributes(attributes)
    persist!(contact)

    "Cadastro atualizado. Nome: #{contact.name.presence || '(vazio)'}. E-mail: #{contact.email.presence || '(vazio)'}."
  end

  private

  # Campo ausente ou vazio fica fora do update: omitir não pode apagar dado que
  # o cliente já tinha dado antes (o modelo não enxerga o cadastro inteiro).
  def attributes_from(input)
    input = input.to_h.with_indifferent_access
    attributes = { name: input[:nome].to_s.strip, email: input[:email].to_s.strip }
    attributes.select { |_field, value| value.present? }
  end
end
