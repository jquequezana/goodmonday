class Target
	include Mongoid::Document
	include Mongoid::Symbolize
	embedded_in :offer

	has_many :achievements

	field :title, type: String
	field :fixed_price, type: Integer, default: 0
  #TODO: 3 цены
	field :prc_price, type: Integer, default: 0
  #TODO: 3 цены
	symbolize :confirm_mode, :in => [:auto, :manual], :default => :auto
	field :confirm_url, type: String
  field :hold, type: Integer, default: 20

  validates :hold, presence: true

	MODERATED_ATTRS = %w[title fixed_price prc_price hold]
	include IsModerated
end
