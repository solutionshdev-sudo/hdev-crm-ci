# Começa permissivo: qualquer membro da conta vê e mexe nos negócios.
# Apertar por papel/participação quando o uso real pedir.
class DealPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    true
  end

  def update?
    true
  end

  def move?
    true
  end

  def destroy?
    true
  end
end
