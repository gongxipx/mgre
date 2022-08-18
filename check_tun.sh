#/bin/bash
localAddr=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
while :
do
	#判断gre隧道是否存在
	tun=$(ip link show | grep tun_olink)
	if [ -z "$tun" ]
	then
		#如果Olink 9929 gre 隧道不存在
		#启动olink gre隧道
		ip link add tun_olink type gre local 51.81.209.104 remote 69.46.75.34 ttl 20 key 2206804525
		ip link set tun_olink up
		sysctl -w net.ipv4.conf.all.rp_filter=2 >> /dev/null 2>&1
		ip route add 1.2.4.8/32 dev tun_olink
		#检测隧道丢包率
		check_packet_loss=$(ping -c 5 -q 1.2.4.8 | grep -oP '\d+(?=% packet loss)')
		if [ $check_packet_loss -lt 30 ]; then
			routes=`ip route | wc -l`
			if [ $routes -lt 100 ]; then
				#add china routes
				curl https://www.olink.cloud/add_cn_route.sh | bash
				sendMssg="【通知】服务器：${localAddr}与Olink_9929_gre隧道已成功连接！"
				echo `date`:$sendMssg >> /home/mgre/log/check_tun.log
				curl https://api.suses.net/?msg=$sendMssg >> /dev/null 2>&1
				sleep 60
			fi
		else
			sendMssg="【告警】服务器：${localAddr}与Olink_9929_gre隧道连接丢包率为${check_packet_loss}%，不连接隧道，1分钟后重新检测！"
			echo `date`:$sendMssg >> /home/mgre/log/check_tun.log
			curl https://api.suses.net/?msg=$sendMssg >> /dev/null 2>&1
			ip link del tun_olink #删除gre隧道
			sleep 60
		fi
	else
		#如果如果Olink 9929 gre 隧道存在，计算前往中国方向的ping丢包率
		packet_loss=$(ping -c 5 -q 1.2.4.8 | grep -oP '\d+(?=% packet loss)')
		if [ $packet_loss -ge 30 ]; then
			#如果丢了2个包以上，判断线路质量不佳
			sendMssg="【告警】服务器：${localAddr}与Olink_9929_gre隧道连接丢包率为${check_packet_loss}%，1分钟后重新检测！"
			echo `date`:$sendMssg  >> /home/mgre/log/check_tun.log
			curl https://api.suses.net/?msg=$sendMssg >> /dev/null 2>&1
			#ip link del tun_olink #删除gre隧道
			sleep 60
		fi
	fi
done
