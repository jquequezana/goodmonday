# coding: utf-8

class RobotController < ApplicationController
	after_filter :set_access_control_headers, :only => [:show]

	def rotator
		@ground = Ground.find(params[:ground_id])
		render :nothing => true, :status => whatever unless @ground
	end

	def show
		sizes = params[:sizes]
		ground = Ground.find(params[:ground_id])
		if !sizes || sizes.empty? || !ground
			render :json => nil
		else
			used_offers = []
			banners = {}
			#
			sizes.each_pair do |size,count_str|
				count = count_str.to_i
				offers = ground.accepted_offers.active.for_advert_size(size).not_in(_id: used_offers)
				offers_count = offers.count
				if offers_count<count
					offers = ground.accepted_offers.active.for_advert_size(size)
					offers_count = offers.count
				end
				if offers_count>=count
					max_count = offers_count-count+1

					n = (Math.log(Random.rand, 0.95)).floor % max_count
					offers = offers.skip(n).limit(count)
					banners[size] = []
					offers.each do |offer|
						adverts = offer.adverts.for_size(size)
						advert = adverts.skip(Random.rand(adverts.count)).limit(1).first
						banners[size] << advert.html_code(size, ground)
						used_offers << offer.id
					end
				elsif offers_count>0
					banners[size] = []
					count.times do
						n = (Math.log(Random.rand, 0.95)).floor % offers_count
						offer = offers.skip(n).limit(1).first
						adverts = offer.adverts.for_size(size)
						advert = adverts.skip(Random.rand(adverts.count)).limit(1).first
						banners[size] << advert.html_code(size, ground)
						used_offers << offer.id
					end
				else
					banners[size] = Array.new(count.to_i, Advert.html_code(size))
					offer = Offer.find_by_mark('goodmonday_referral')
					if offer
						adverts = offer.adverts.for_size(size)
						unless adverts.empty?
              advert = adverts.first
              banners[size] = Array.new(count.to_i, advert.html_code(size, ground))
						end
					end
				end

			end
			#
			#sizes.each_pair do |size,count|
			#	banners[size] = Array.new(count.to_i, "<img src='http://placehold.it/#{size}' />")
			#end
			#
			render :json => banners.to_json
		end
	end

	def redirect

		url = 'http://goodmonday.ru' #fallback url

		ground_id = params[:ground_id]
		offer_id = params[:offer_id]

		ground = Ground.find(ground_id)
		offer = Offer.find(offer_id)
		webmaster = ground.webmaster

		if offer.accept_custom_urls && params[:url] && !params[:url].empty? && params[:url].starts_with?('http')
			url = params[:url]
		elsif (defined? advert) && advert && !advert.url.empty?
			url = advert.url
		elsif !offer.landing_url.empty?
			url = offer.landing_url
		elsif !offer.url.empty?
			url = offer.url
		end

		ip = request.remote_ip
		if BlackIp.exclude(ip) && check_for_suspicions(request)
			if ground.find_offer_permission(offer_id).state==:accepted
				visitor = Visitor.new
				visitor.ground = ground
				visitor.offer = offer
				visitor.initial_ip = ip
				visitor.initial_page = request.referer
				visitor.user_agent = request.user_agent

				if (defined? advert) && advert
					visitor.advert_id = advert.id
				end

				sub_id = nil
				if params[:sub_id] && !params[:sub_id].empty?
					sub_id = params[:sub_id]
					if sub_id && !sub_id.empty?
						unless webmaster.sub_ids.include? sub_id
							webmaster.sub_ids << sub_id
							webmaster.save
						end
					else
						sub_id = nil
					end
				end

				if visitor.save
					cookies[offer.id.to_s] = { :value => visitor.id.to_s, :expires => offer.cookie_time.days.from_now }
					#:path - The path for which this cookie applies. Defaults to the root of the application.
					#:domain - The domain for which this cookie applies.
				end
			end
		end

		#collecting statistic:
		StatCounter.register_click(ground, offer, sub_id)

		if offer.redirect_options && !offer.redirect_options.empty?
			redirect_options = offer.redirect_options
			if (defined? visitor) && visitor
				redirect_options.gsub!('%{visitor_id}', visitor.id.to_s)
				redirect_options.gsub!('%{visitor_idn}', visitor.id.to_s.to_i(16).to_s)
			end
			redirect_options.gsub!('%{webmaster_id}', webmaster.id.to_s) if (defined? webmaster) && webmaster
			if (defined? ground) && ground
				redirect_options.gsub!('%{ground_id}', ground.id.to_s)
				redirect_options.gsub!('%{ground_alt}', ground.alternative_id.to_s)
			end
			url = add_url_options(url, redirect_options)
		end

		redirect_to url
	end

	def visit
		if params[:offer_id]=='OFFER_ID'
			logger.info "WARNING! Wrong script installed! Referer: #{request.referer}."
			return
		end
		offer = Offer.find(params[:offer_id])
		if cookies[offer.id.to_s] && !cookies[offer.id.to_s].empty?
			visitor_id = cookies[offer.id.to_s]
			visitor = Visitor.find(visitor_id)
			if visitor
				visitor.page_visits.create(:ip => request.remote_ip, :page => request.referer)
			end
		end
		#response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
		#response.headers["Pragma"] = "no-cache"
		#response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
	end

	def target
		ip = request.remote_ip
		if BlackIp.exclude(ip) && check_for_suspicions(request)
			offer = Offer.find(params[:offer_id])
			if offer && offer.active?
				target_id = params[:target_id]
				target = offer.targets.find(target_id)
				if target && target.active?
					if cookies[offer.id.to_s] && !cookies[offer.id.to_s].empty?
						visitor_id = cookies[offer.id.to_s]
					elsif target.cookieless_achievement && params[:visitor] && !params[:visitor].empty?
						visitor_id = params[:visitor]
					end
					if (defined? visitor_id) && visitor_id && !visitor_id.empty?
						visitor = Visitor.find(visitor_id)
						if visitor && visitor.offer == offer
							if target.repeatable || Achievement.where(:visitor_id => visitor_id, :target_id => target_id).size==0 #запрещаем двойное взятие цели
								achievement = Achievement.new
								achievement.build_prototype(offer, visitor, target_id)
								achievement.ip = ip
								achievement.page = request.referer
								if params[:order_id] && !params[:order_id].empty?
									achievement.order_id = params[:order_id]
								end
								if target.confirm_mode == :auto
									if target.set_price_on_achievement && achievement.order_id && params[:amount] && !params[:amount].empty? && params[:chk] && !params[:chk].empty?
										amount = params[:amount].to_f
										chk = params[:chk].to_s.downcase
										chk_string1 = "#{offer.id.to_s}/target/#{target.id.to_s}/#{achievement.order_id}/#{"%.2f" % amount}/#{offer.hash_key}"
										chk_string2 = "#{offer.id.to_s}/target/#{target.id.to_s}/#{achievement.order_id}/#{params[:amount].to_s}/#{offer.hash_key}"
										md5_1 = Digest::MD5.hexdigest(chk_string1)
										md5_2 = Digest::MD5.hexdigest(chk_string2)
										if chk==md5_1 || chk==md5_2
											achievement.accept(target.webmaster_price(amount), target.advertiser_price(amount))
										else
											achievement.additional_info = "Не совпал хэш :(\nприслан: #{chk}\nстрока для проверки: #{chk_string}\nmd5: #{md5_1} или #{md5_2}"
										end
									else
										achievement.accept(target.webmaster_price, target.advertiser_price)
									end
								end
								achievement.save
							end
						end
					end
				end
			end
		end
		redirect_to "/pixel.png"
	end

	protected

	def check_for_suspicions(request)
		return true #TODO: temporary disabled check
		#reason = nil
		#reason = "#{reason}Пустой referer. " if !request.referer || request.referer.empty?
		#reason = "#{reason}Пустой user_agent. " if !request.user_agent || request.user_agent.empty?
		#Suspicion.create(:ip => request.remote_ip, :reason_text => reason) unless reason.nil?
		#reason.nil?
	end

	def set_access_control_headers
		headers['Access-Control-Allow-Origin'] = '*'
		headers['Access-Control-Request-Method'] = '*'
	end

	def add_url_options(url, options)
		if url.include? '?'
			url = "#{url}&#{options}"
		else
			url = "#{url}?#{options}"
		end
		url
	end

end
