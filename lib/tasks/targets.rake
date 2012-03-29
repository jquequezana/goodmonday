namespace :targets do
	task :confirm => :environment do
		require 'hpricot'
	 	require 'open-uri'

		Achievement.pending.each do |achievement|
			unless achievement.order_id
				#exception
			end
			order_id = achievement.order_id
			offer = achievement.offer
			target = offer.targets.find(achievement.target_id)
			url = target.confirm_url
			if url.include? '?'
				url = "#{url}&targets=#{order_id}"
			else
				url = "#{url}?targets=#{order_id}"
			end
			doc = Hpricot(open(url))

			(doc/:item).each do |item|
				id = item.at('id').inner_text
				if id==order_id
					status = item.at('status').inner_text.to_i
					price = item.at('price').inner_text.to_f

					if [1,3].include? status
						if status==1
							achievement.status = :accepted
							achievement.price = target.fixed_price + target.prc_price*price/100
						elsif status==3
							achievement.status = :denied
						end
						achievement.save
					end
				end
			end
		end
	end
end
