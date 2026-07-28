module Ai
  # Falha esperada de uma ferramenta (input inválido, registro não encontrado).
  # A mensagem volta pro modelo como tool_result de erro, então ele corrige e
  # tenta de novo — nunca colocar detalhe interno aqui.
  class ToolError < StandardError; end
end
