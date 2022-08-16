#/bin/bash

function install_tun(){
	mkdir -p /home/mgre
	cd /home/mgre
	#获取本机IP地址
	localAddr=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
	#输入密钥
	read -p "请输入隧道密钥：" tunKey


	#安装iptables
	apt-get install iptables -y >> /dev/null 2>&1
	apt-get install iptables-persistent -y >> /dev/null 2>&1
	systemctl enable netfilter-persistent.service >> /dev/null 2>&1 #开机自启动#

	#第一次安装清空nat链和残余文件
	rm -rf install_tun.sh added_server.sh
	iptables -t nat -F
	/etc/init.d/netfilter-persistent save >> /dev/null 2>&1   #保存规则#
	/etc/init.d/netfilter-persistent reload  >> /dev/null 2>&1  #生效规则#

	#选择9929GRE供应商
	read -p "请选择9929 GRE供应商（tun_olik或oulucloud）：" provider

	echo "sysctl -w net.ipv4.ip_forward=1 >> /dev/null 2>&1
ip link del tun_suses  
ip tunnel add tun_suses mode gre local ${localAddr} key ${tunKey} ttl 255
ip addr add 10.0.1.1/32 dev tun_suses
ip link set tun_suses up" > install_tun.sh
	bash install_tun.sh
	iptables -t filter -I FORWARD -i tun_suses -o ${provider} -j ACCEPT
	/etc/init.d/netfilter-persistent save >> /dev/null 2>&1
	touch added_server.sh
	#设置开机自启动
	echo "#/bin/bash
bash /home/install_tun.sh
bash /home/added_server.sh" > /home/autostart.sh
	echo "
[Unit]
Description=GRE

[Service]
User=root
Group=root
RestartSec=20s
Restart=always
ExecStart=/bin/bash /home/autostart.sh

[Install]
WantedBy=default.target" >> /etc/systemd/system/gre.service
	systemctl enable gre.service
	echo "GRE隧道安装完成！"
}

function add_server(){
	cd /home/mgre
	#添加需要GRE隧道优化的服务器
	echo "已经占用的隧道内网IP："
	ip neighbour show | grep "tun_suses"
	read -p "需要优化的服务器隧道内网IP：" lanIp
	read -p "需要GRE隧道优化的服务器IP：" remoteIp
	read -p "备注：" name
	echo -e "# 隧道内网IP：${lanIp}  需要GRE隧道优化的服务器IP：${remoteIp}  备注：${name}\nip neighbour add $lanIp lladdr $remoteIp dev tun_suses" >> added_server.sh
	bash added_server.sh
	
	iptables -t nat -I POSTROUTING -s $lanIp -j SNAT --to $remoteIp  -m comment --comment ${name}
	/etc/init.d/netfilter-persistent save >> /dev/null 2>&1
}


function rm_iptables_rules(){
	cd /home/mgre
	echo "iptables nat 转发表"
	iptables -nL -t nat --line-numbers | grep "SNAT"
	read -p "请输入您要删除规则的内网IP：" removedIp
	ip neighbour delete ${removedIp} dev tun_suses
	#从添加的脚本中删除
	sed -i "/# 隧道内网IP：${lanIp}.*/d" added_server.sh
	sed -i "/ip neighbour add ${removedIp} lladdr.*/d" added_server.sh
	#删除防火墙规则
	read -p "请输入您要删除规则的序号：" num
	iptables -t nat -D POSTROUTING $num
	/etc/init.d/netfilter-persistent save >> /dev/null 2>&1
	#显示删除后的防火墙规则
	echo "iptables nat 转发表"
	iptables -nL -t nat --line-numbers | grep "SNAT"
	echo "ip neighbour gre邻居表"
	ip neighbour show | grep "tun_suses"
}
function uninstall_tun(){
	cd /home/mgre
	ip link del tun_suses
	rm -rf install_tun.sh added_server.sh
}

echo "######################################################"
echo "#                                                    #"
echo "#            GRE9929隧道复用脚本服务端               #"
echo "#             隧道内网网段10.0.1.0/24                #"
echo "#                                                    #"
echo "######################################################"
echo "请输入"
select var in "GRE隧道安装" "添加优化服务器" "查看转发规则" "删除转发规则" "卸载GRE隧道" "退出"
do
    case $var in
        GRE隧道安装)
		install_tun
        ;;
        添加优化服务器)
		add_server
        ;;
		查看转发规则)
		echo "iptables nat 转发表"
		iptables -nL -t nat --line-numbers | grep "SNAT"
		echo "ip neighbour gre邻居表"
		ip neighbour show | grep "tun_suses"
        ;;
		删除转发规则)
		rm_iptables_rules
        ;;
		卸载GRE隧道)
		uninstall_tun
        ;;
        退出)
        echo "Bye!"
        exit
    esac
done
