# coding: utf-8

namespace :achievements do
  namespace :collect do

    def find_marked_offer(marker)
      return Offer.where(:achievement_task_marker => marker).first
    end

    def find_marked_target(offer, marker)
      return offer.targets.where(:achievement_task_marker => marker).first
    end

    task :aviasales => :environment do
      offer = find_marked_offer('aviasales')
      next unless offer
      target = find_marked_target(offer, 'aviasales_booking')
      next unless target

      require 'hpricot'
      require 'open-uri'

      url = "http://nano.aviasales.ru/partners/statistics/api.xml?start_time=#{(Date.today-2.months).to_s}T00:00:00&end_time=#{Date.tomorrow.to_s}T00:00:00"
      username = 'perepechenkov@goodmonday.ru'
      password = 'sCg3MCZp'

      doc = Hpricot(open(url, :http_basic_authentication => [username, password]))
      (doc/:bookings/:booking).each do |item|
        order_number = item.at('order-number').inner_text
        marker = item.at('marker').inner_text
        order_id = "#{marker}.#{order_number}"
        state = item.at('state').inner_text
        achievement = offer.achievements.where(:order_id => order_id).first
        if achievement
          next if achievement.is_accepted?
          if state=='paid'
            price = item.at('price').inner_text.to_f
            achievement.accept(target.webmaster_price(price), target.advertiser_price(price))
            achievement.save
          end
        else
          visitor_id = marker.split('.').second
          visitor = Visitor.find(visitor_id)
          achievement = Achievement.new
          achievement.build_prototype(offer, visitor, target.id)
          achievement.order_id = order_id
          if state=='paid'
            price = item.at('price').inner_text.to_f
            achievement.accept(target.webmaster_price(price), target.advertiser_price(price))
          end
          achievement.created_at = DateTime.parse(item.at('booked-at').inner_text+' +0400')
          achievement.save
        end
      end
    end

    task :topshop => :environment do
      offer = find_marked_offer('topshop')
      next unless offer
      target = find_marked_target(offer, 'topshop_order')
      next unless target

      require 'hpricot'
      require 'open-uri'

      url = "http://www.top-shop.ru/affiliates/report/23916/7e22c6e6976eab5018024fb2a11e9c6d"

      doc = Hpricot(open(url))
      (doc/:payment_list/:payment).each do |item|
        #
        order_id = item.at('order_id').inner_text
        marker = item.at('key').inner_text
        state = item.at('status').inner_text
        price = item.at('reward').inner_text.to_f
        advertiser_price = Money.new(price)
        webmaster_price = advertiser_price*0.7
        achievement = offer.achievements.where(:order_id => order_id).first
        if achievement
          if state=='20' && achievement.state!=:accepted
            achievement.accept(webmaster_price, advertiser_price)
            achievement.save
          elsif state=='30' && achievement.state!=:denied
            achievement.cancel!
            achievement.save
          end
        else
          visitor_id = marker.split('?visitor=').second
          next unless visitor_id
          visitor = Visitor.find(visitor_id)
          achievement = Achievement.new
          achievement.build_prototype(offer, visitor, target.id)
          achievement.order_id = order_id
          if state=='20'
            achievement.accept(webmaster_price, advertiser_price)
          elsif state=='30'
            achievement.cancel!
          end
          achievement.created_at = DateTime.parse(item.at('date').inner_text+' +0400')
          achievement.save
        end
      end
    end

    task :domadengi => :environment do
      offer = find_marked_offer('domadengi')
      next unless offer
      target = find_marked_target(offer, 'domadengi_order')
      next unless target

      require 'hpricot'
      require 'open-uri'

      url = "http://secure.domadengi.ru/partner/xml/5194c858bdf337b3bdb1b4b5fb507d97/report.xml"

      doc = Hpricot(open(url))
      (doc/:item).each do |item|
        #
        order_id = item.at('id_cron').inner_text
        state = item.at('status').inner_text
        price = item.at('price').inner_text.to_f
        achievement = offer.achievements.where(:order_id => order_id).first
        if achievement
          if state=='Займ одобрен' && achievement.state!=:accepted
            achievement.accept(target.webmaster_price(price), target.advertiser_price(price))
            achievement.save
          elsif state=='Отказ' && achievement.state!=:denied
            achievement.cancel!
            achievement.save
          end
        else
          visitor_id = item.at('manager_name').inner_text
          next unless visitor_id
          next if visitor_id.empty?
          visitor = Visitor.where(:_id => visitor_id).first
          next unless visitor
          #
          achievement = Achievement.new
          achievement.build_prototype(offer, visitor, target.id)
          achievement.order_id = order_id
          if state=='Займ одобрен'
            achievement.accept(target.webmaster_price(price), target.advertiser_price(price))
          elsif state=='Отказ'
            achievement.cancel!
          end
          achievement.created_at = DateTime.parse(item.at('timestamp_x').inner_text+' +0400')
          achievement.save
        end
      end
    end

    task :nikitaonline => :environment do
      offers = {}
      offers[3] = find_marked_offer('nikitaonline_dom3')
      offers[9] = find_marked_offer('nikitaonline_sphere')
      offers[34] = find_marked_offer('nikitaonline_rappelz')
      offers[40] = find_marked_offer('nikitaonline_4story')
      offers[42] = find_marked_offer('nikitaonline_dragononline')
      offers[44] = find_marked_offer('nikitaonline_fantazium')
      offers[48] = find_marked_offer('nikitaonline_karos')
      offers[54] = find_marked_offer('nikitaonline_kok')
      #offers[503] = find_marked_offer('nikitaonline') #Lost Magic

      targets = {}
      offers.each do |key, offer|
        targets[key] = find_marked_target(offer, 'nikitaonline_payments') if offer
      end

      require 'hpricot'
      require 'open-uri'
      require 'digest/md5'

      uid = '8504521'
      pwd = 'j8ti48r'
      date_from = (Date.today-1.month).to_s
      date_to = Date.yesterday.to_s
      hash = Digest::MD5.hexdigest(uid+Digest::MD5.hexdigest(pwd)+date_from+date_to)
      url = "http://shop.nikitaonline.ru/xml/refstat_partner_xml.php?stat=payments&dfrom=#{date_from}&dto=#{date_to}&pid=all&parent_uid=#{uid}&format=xml&groupby_days=1&groupby_pids=1&md5=#{hash}"

      doc = Hpricot(open(url))
      (doc/:stats/:stat).each do |item|
        #
        visitor_id = item.at('external_key').inner_text
        day = item.at('day').inner_text
        sum = item.at('sum').inner_text.to_f
        order_id = visitor_id.to_s+'='+day
        pid = item.at('pid').inner_text.to_i

        offer = offers[pid]
        next unless offer
        target = targets[pid]
        next unless target

        next if sum==0.0

        achievement = offer.achievements.where(:order_id => order_id).first
        next if achievement

        next unless visitor_id
        next if visitor_id.empty?
        visitor = Visitor.where(:_id => visitor_id).first
        next unless visitor

        achievement = Achievement.new
        achievement.build_prototype(offer, visitor, target.id)
        achievement.order_id = order_id
        achievement.accept(target.webmaster_price(sum), target.advertiser_price(sum))
        achievement.created_at = DateTime.parse(day)
        achievement.save
      end
    end

    task :all => [:aviasales, :topshop, :domadengi, :nikitaonline]
  end

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
      next if !url || url.empty?
			if url.include? '?'
				url = "#{url}&targets=#{order_id}"
			else
				url = "#{url}?targets=#{order_id}"
			end
			doc = Hpricot(open(url))

			(doc/:items/:item).each do |item|
				id = item.at('id').inner_text
				if id==order_id
					status = item.at('status').inner_text.to_i
					price = item.at('price').inner_text.to_f

          #1 - :accepted
          #2 - :pending
          #3 - :denied
					if [1,3].include? status
						if status==1
              achievement.accept(target.webmaster_price(price), target.advertiser_price(price))
						elsif status==3
							achievement.cancel!
						end
						achievement.save
					end
				end
			end
		end
  end

  task :pay => :environment do
    Achievement.accepted.unpaid.where(:hold_date.lte => Date.today).each do |achievement|
      achievement.pay
    end

  end

end
