class Payment
  include Mongoid::Document
 	include Mongoid::Timestamps
  embedded_in :discussion

 	field :amount, :type => Integer
end
