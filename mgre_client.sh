#/bin/bash
function link_tun(){
	#获取本机IP地址
	localAddr=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
	read -p "请输入GRE隧道服务端IP：" remoteIp
	read -p "请输入GRE隧道内网IP：" lanIp
	read -p "请输入GRE隧道服务端密钥：" tunKey
	echo "ip link del tun_suses >> /dev/null 2>&1
ip tunnel add tun_suses mode gre local ${localAddr} remote $remoteIp key ${tunKey} ttl 255
ip addr add ${lanIp}/30 dev tun_suses
ip link set tun_suses up
sysctl -w net.ipv4.conf.all.rp_filter=2 >> /dev/null 2>&1
ip route add 1.2.4.8/32 dev tun_suses
curl https://raw.githubusercontent.com/gongxipx/mgre/main/add_cn_route.sh | bash >> /dev/null 2>&1" > link_tun.sh
	bash link_tun.sh
	echo "tun_suses is up and china routes added"
}

function uninstall_tun(){
	ip link del tun_suses
}



echo "######################################################"
echo "#                                                    #"
echo "#            GRE9929隧道复用脚本客户端               #"
echo "#             隧道内网网段10.0.1.0/24                #"
echo "#                                                    #"
echo "######################################################"
echo "请输入"
select var in "连接GRE隧道" "卸载GRE隧道" "退出"
do
    case $var in
        连接GRE隧道)
		link_tun
        ;;
		卸载GRE隧道)
		uninstall_tun
        ;;
        退出)
        echo "Bye!"
        exit
    esac
done
