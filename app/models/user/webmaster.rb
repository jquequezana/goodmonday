class Webmaster < Member
	include Mongoid::Symbolize

	has_many :grounds
	has_many :achievements

  field :sub_ids, type: Array, default: []

	symbolize :rank, :in => [:bronze, :silver, :gold], :default => :bronze
end
