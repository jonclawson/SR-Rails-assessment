module OrdersHelper
  def state_badge_class(state)
    case state.to_s
    when "pending"
      "bg-gray-100 text-gray-800"
    when "approved"
      "bg-blue-100 text-blue-800"
    when "shipped"
      "bg-purple-100 text-purple-800"
    when "delivered"
      "bg-green-100 text-green-800"
    when "canceled"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
