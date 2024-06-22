```bash
#!/bin/bash

if readlink /proc/$$/exe | grep -q "dash"; then
	echo 'Este instalador necesita ser ejecutado con "bash", no "sh".'
	exit
fi

read -N 999999 -t 0.001

if uname -r | cut -d "." -f 1 -eq 2; then
	echo "El sistema está ejecutando un kernel antiguo, que es incompatible con este instalador."
	exit
fi

if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
	group_name="nogroup"
elif test -e /etc/debian_version; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
	group_name="nogroup"
else
	echo "Este instalador parece estar ejecutándose en una distribución no compatible.
Las distribuciones compatibles son Ubuntu 20.04 y Debian 10."
	exit
fi

if test "$os" = "ubuntu" && test "$os_version" -ne 2004; then
	echo "Ubuntu 20.04 es requerido para usar este instalador.
Esta versión de Ubuntu no es compatible."
	exit
fi

if test "$os" = "debian" && test "$os_version" -ne 10; then
	echo "Debian 10 es requerido para usar este instalador.
Esta versión de Debian no es compatible."
	exit
fi

if ! grep -q sbin <<< "$PATH"; then
	echo '$PATH no incluye sbin. Intente usar "su -" en lugar de "su".'
	exit
fi

if test "$EUID" -ne 0; then
	echo "Este instalador necesita ser ejecutado con privilegios de superusuario."
	exit
fi

if ! test -e /dev/net/tun || ! exec 7<>/dev/net/tun 2>/dev/null; then
	echo "El sistema no tiene el dispositivo TUN disponible.
TUN necesita ser habilitado antes de ejecutar este instalador."
	exit
fi

new_client () {
	{
	cat /etc/openvpn/server/client-common.txt
	echo "<ca>"
	cat /etc/openvpn/server/easy-rsa/pki/ca.crt
	echo "</ca>"
	echo "<cert>"
	sed -ne '/BEGIN CERTIFICATE/,$ p' /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt
	echo "</cert>"
	echo "<key>"
	cat /etc/openvpn/server/easy-rsa/pki/private/"$client".key
	echo "</key>"
	echo "<tls-crypt>"
	sed -ne '/BEGIN OpenVPN Static key/,$ p' /etc/openvpn/server/tc.key
	echo "</tls-crypt>"
	} > /var/www/html/"$client".ovpn
}

if ! test -e /etc/openvpn/server/server.conf; then
	clear
	echo '¡Bienvenido al instalador de OpenVPN road warrior!'
	if ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}' -eq 1; then
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
	else
		number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
		echo
		echo "¿Qué dirección IPv4 debería usarse?"
		ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
		read -p "Dirección IPv4 1: " ip_number
		until test -z "$ip_number" || test "$ip_number" =~ ^[0-9]+$ && test "$ip_number" -le "$number_of_ip"; do
			echo "$ip_number: selección inválida."
			read -p "Dirección IPv4 1: " ip_number
		done
		test -z "$ip_number" && ip_number="1"
		ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
	fi
	if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
		echo
		echo "Este servidor está detrás de NAT. ¿Cuál es la dirección IPv4 pública o el nombre de host?"
		get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
		read -p "Dirección IPv4 pública / nombre de host $get_public_ip: " public_ip
		until test -n "$get_public_ip" || test -n "$public_ip"; do
			echo "Entrada inválida."
			read -p "Dirección IPv4 pública / nombre de host: " public_ip
		done
		test -z "$public_ip" && public_ip="$get_public_ip"
	fi
	if ip -6 addr | grep -c 'inet6 [23]' -eq 1; then
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')
	fi
	if ip -6 addr | grep -c 'inet6 [23]' -gt 1; then
		number_of_ip6=$(ip -6 addr | grep -c 'inet6 [23]')
		echo
		echo "¿Qué dirección IPv6 debería usarse?"
		ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | nl -s ') '
		read -p "Dirección IPv6 1: " ip6_number
		until test -z "$ip6_number" || test "$ip6_number" =~ ^[0-9]+$ && test "$ip6_number" -le "$number_of_ip6"; do
			echo "$ip6_number: selección inválida."
			read -p "Dirección IPv6 1: " ip6_number
		done
		test -z "$ip6_number" && ip6_number="1"
		ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | sed -n "$ip6_number"p)
	fi
	echo
	echo "¿Qué protocolo debería usar OpenVPN?"
	echo "   1) UDP (predeterminado)"
	echo "   2) TCP"
	read -p "Protocolo 1: " protocol
	until test -z "$protocol" || test "$protocol" =~ ^[12]$; do
		echo "$protocol: selección inválida."
		read -p "Protocolo 1: " protocol
	done
	case "$protocol" in
		1|"")
		protocol=udp
		;;
		2)
		protocol=tcp
		;;
	esac
	echo
	echo "¿Qué puerto debería usar OpenVPN?"
	read -p "Puerto 1194: " port
	until test -z "$port" || test "$port" =~ ^[0-9]+$ && test "$port" -le 65535; do
		echo "$port: puerto inválido."
		read -p "Puerto 1194: " port
	done
	test -z "$port" && port="1194"
	echo
	echo "Seleccione un servidor DNS para los clientes:"
	echo "   1) Resolutores del sistema actual"
	echo "   2) Google"
	echo "   3) 1.1.1.1 (predeterminado)"
	echo "   4) OpenDNS"
	echo "   5) Quad9"
	echo "   6) AdGuard"
	read -p "Servidor DNS 3: " dns
	until test -z "$dns" || test "$dns" =~ ^[1-6]$; do
		echo "$dns

: selección inválida."
		read -p "Servidor DNS 3: " dns
	done
	test -z "$dns" && dns="3"
	echo
	echo "Ingrese un nombre para el primer cliente:"
	read -p "Nombre cliente: " unsanitized_client
	client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
	test -z "$client" && client="client"
	echo
	echo "La instalación de OpenVPN está lista para comenzar."
	if ! systemctl is-active --quiet firewalld.service && ! hash iptables 2>/dev/null; then
		if test "$os" = "centos" || test "$os" = "fedora"; then
			firewall="firewalld"
			echo "firewalld, que es necesario para gestionar tablas de enrutamiento, también se instalará."
		elif test "$os" = "debian" || test "$os" = "ubuntu"; then
			firewall="iptables"
		fi
	fi
	read -n1 -r -p "Presione cualquier tecla para continuar..."
	if systemd-detect-virt -cq; then
		mkdir /etc/systemd/system/openvpn-server@server.service.d/ 2>/dev/null
		echo "[Service]
LimitNPROC=infinity" > /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
	fi
	if test "$os" = "debian" || test "$os" = "ubuntu"; then
		apt-get update
		apt-get install -y openvpn openssl ca-certificates $firewall
	elif test "$os" = "centos"; then
		yum install -y epel-release
		yum install -y openvpn openssl ca-certificates tar $firewall
	else
		dnf install -y openvpn openssl ca-certificates tar $firewall
	fi
	if test "$firewall" = "firewalld"; then
		systemctl enable --now firewalld.service
	fi
	easy_rsa_url='https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz'
	mkdir -p /etc/openvpn/server/easy-rsa/
	{ wget -qO- "$easy_rsa_url" 2>/dev/null || curl -sL "$easy_rsa_url" ; } | tar xz -C /etc/openvpn/server/easy-rsa/ --strip-components 1
	chown -R root:root /etc/openvpn/server/easy-rsa/
	cd /etc/openvpn/server/easy-rsa/
	./easyrsa init-pki
	./easyrsa --batch build-ca nopass
	EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-server-full server nopass
	EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	cp pki/ca.crt pki/private/ca.key pki/issued/server.crt pki/private/server.key pki/crl.pem /etc/openvpn/server
	chown nobody:"$group_name" /etc/openvpn/server/crl.pem
	chmod o+x /etc/openvpn/server/
	openvpn --genkey --secret /etc/openvpn/server/tc.key
	echo '-----BEGIN DH PARAMETERS-----
MIIBCAKCAQEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEoXJf//////////wIBAg==
-----END DH PARAMETERS-----' > /etc/openvpn/server/dh.pem
	echo "local $ip
port $port
proto $protocol
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
auth SHA512
tls-crypt tc.key
topology subnet
server 10.8.0.0 255.255.255.0" > /etc/openvpn/server/server.conf
	if test -z "$ip6"; then
		echo 'push "redirect-gateway def1 bypass-dhcp"' >> /etc/openvpn/server/server.conf
	else
		echo 'server-ipv6 fddd:1194:1194:1194::/64' >> /etc/openvpn/server/server.conf
		echo 'push "redirect-gateway def1 ipv6 bypass-dhcp"' >> /etc/openvpn/server/server.conf
	fi
	echo 'ifconfig-pool-persist ipp.txt' >> /etc/openvpn/server/server.conf
	case "$dns" in
		1)
			if grep -q '^nameserver 127.0.0.53' "/etc/resolv.conf"; then
				resolv_conf="/run/systemd/resolve/resolv.conf"
			else
				resolv_conf="/etc/resolv.conf"
			fi
			grep -v '^#\|^;' "$resolv_conf" | grep '^nameserver' | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | while read line; do
				echo "push \"dhcp-option DNS $line\"" >> /etc/openvpn/server/server.conf
			done
		;;
		2)
			echo 'push "dhcp-option DNS 8.8.8.8"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 8.8.4.4"' >> /etc/openvpn/server/server.conf
		;;
		3)
			echo 'push "dhcp-option DNS 1.1.1.1"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 1.0.0.1"' >> /etc/openvpn/server/server.conf
		;;
		4)
			echo 'push "dhcp-option DNS 208.67.222.222"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 208.67.220.220"' >> /etc/openvpn/server/server.conf
		;;
		5)
			echo 'push "dhcp-option DNS 9.9.9.9"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 149.112.112.112"' >> /etc/openvpn/server/server.conf
		;;
		6)
			echo 'push "dhcp-option DNS 176.103.130.130"' >> /etc/openvpn/server/server.conf
			echo 'push "dhcp-option DNS 176.103.130.131"' >> /etc/openvpn/server/server.conf
		;;
	esac
	echo "keepalive 10 120
cipher AES-256-CBC
user nobody
group $group_name
persist-key
persist-tun
status openvpn-status.log
verb 3
duplicate-cn
crl-verify crl.pem" >> /etc/openvpn/server/server.conf
	if test "$protocol" = "udp"; then
		echo "explicit-exit-notify" >> /etc/openvpn/server/server.conf
	fi
	echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/30-openvpn-forward.conf
	echo 1 > /proc/sys/net/ipv4/ip_forward
	if test -n "$ip6"; then
		echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.d/30-openvpn-forward.conf
		echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
	fi
	if systemctl is-active --quiet firewalld.service; then
		firewall-cmd --add-port="$port"/"$protocol"
		firewall-cmd --zone=trusted --add-source=10.8.0.0/24
		firewall-cmd --permanent --add-port="$port"/"$protocol"
		firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24
		firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
		firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
		if test -n "$ip6"; then
			firewall-cmd --zone=trusted --

add-source=fddd:1194:1194:1194::/64
			firewall-cmd --permanent --zone=trusted --add-source=fddd:1194:1194:1194::/64
			firewall-cmd --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
			firewall-cmd --permanent --direct --add-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
		fi
	else
		iptables_path=$(command -v iptables)
		ip6tables_path=$(command -v ip6tables)
		if test $(systemd-detect-virt) = "openvz" && readlink -f "$(command -v iptables)" | grep -q "nft" && hash iptables-legacy 2>/dev/null; then
			iptables_path=$(command -v iptables-legacy)
			ip6tables_path=$(command -v ip6tables-legacy)
		fi
		echo "[Unit]
Before=network.target
[Service]
Type=oneshot
ExecStart=$iptables_path -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStart=$iptables_path -I INPUT -p $protocol --dport $port -j ACCEPT
ExecStart=$iptables_path -I FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStart=$iptables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$iptables_path -t nat -D POSTROUTING -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to $ip
ExecStop=$iptables_path -D INPUT -p $protocol --dport $port -j ACCEPT
ExecStop=$iptables_path -D FORWARD -s 10.8.0.0/24 -j ACCEPT
ExecStop=$iptables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" > /etc/systemd/system/openvpn-iptables.service
		if test -n "$ip6"; then
			echo "ExecStart=$ip6tables_path -t nat -A POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStart=$ip6tables_path -I FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStart=$ip6tables_path -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ExecStop=$ip6tables_path -t nat -D POSTROUTING -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to $ip6
ExecStop=$ip6tables_path -D FORWARD -s fddd:1194:1194:1194::/64 -j ACCEPT
ExecStop=$ip6tables_path -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT" >> /etc/systemd/system/openvpn-iptables.service
		fi
		echo "RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" >> /etc/systemd/system/openvpn-iptables.service
		systemctl enable --now openvpn-iptables.service
	fi
	if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && test "$port" != 1194; then
		if ! hash semanage 2>/dev/null; then
			if test "$os_version" -eq 7; then
				yum install -y policycoreutils-python
			else
				dnf install -y policycoreutils-python-utils
			fi
		fi
		semanage port -a -t openvpn_port_t -p "$protocol" "$port"
	fi
	test -n "$public_ip" && ip="$public_ip"
	echo "client
dev tun
proto $protocol
remote $ip $port
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA512
cipher AES-256-CBC
ignore-unknown-option block-outside-dns
block-outside-dns

verb 3" > /etc/openvpn/server/client-common.txt
	systemctl enable --now openvpn-server@server.service
	new_client
	echo
	echo "¡Terminado!"
	echo
	echo "La configuración del cliente está disponible en: /var/www/html/$client.ovpn"
	echo "Nuevos clientes se pueden añadir ejecutando este script nuevamente."
else
	clear
	echo "OpenVPN ya está instalado."
	echo
	echo "Seleccione una opción:"
	echo "   1) Añadir un nuevo cliente"
	echo "   2) Revocar un cliente existente"
	echo "   3) Eliminar OpenVPN"
	echo "   4) Salir"
	read -p "Opción: " option
	until test "$option" =~ ^[1-4]$; do
		echo "$option: selección inválida."
		read -p "Opción: " option
	done
	case "$option" in
		1)
			echo
			echo "Proporcione un nombre para el cliente:"
			read -p "Nombre: " unsanitized_client
			client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			while test -z "$client" || test -e /etc/openvpn/server/easy-rsa/pki/issued/"$client".crt; do
				echo "$client: nombre inválido."
				read -p "Nombre: " unsanitized_client
				client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
			done
			cd /etc/openvpn/server/easy-rsa/
			EASYRSA_CERT_EXPIRE=3650 ./easyrsa build-client-full "$client" nopass
			new_client
			echo
			echo "$client añadido. Configuración disponible en: /var/www/html/$client.ovpn"
			exit
		;;
		2)
			number_of_clients=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep -c "^V")
			if test "$number_of_clients" = 0; then
				echo
				echo "¡No hay clientes existentes!"
				exit
			fi
			echo
			echo "Seleccione el cliente a revocar:"
			tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			read -p "Cliente: " client_number
			until test "$client_number" =~ ^[0-9]+$ && test "$client_number" -le "$number_of_clients"; do
				echo "$client_number: selección inválida."
				read -p "Cliente: " client_number
			done
			client=$(tail -n +2 /etc/openvpn/server/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$client_number"p)
			echo
			read -p "Confirmar revocación de $client? [y/N]: " revoke
			until test "$revoke" =~ ^[yYnN]*$; do
				echo "$revoke: selección inválida."
				read -p "Confirmar revocación de $client? [y/N]: " revoke
			done
			if test "$revoke" =~ ^[yY]$; then
				cd /etc/openvpn/server/easy-rsa/
				./easyrsa --batch revoke "$client"
				EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
				rm -f /etc/openvpn/server/crl.pem
				cp /etc/openvpn/server/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
				chown nobody:"$group_name" /etc/openvpn/server/crl.pem
				echo
				echo "$client revocado!"
			else
				echo
				echo "¡Revocación de $client abortada!"
			fi
			exit
		;;
		3)
			echo
			read -p "Confirmar eliminación de OpenVPN? [y/N]: " remove
			until test "$remove" =~ ^[yYnN]*$; do
				echo "$remove: selección inválida."
				read -p "Confirmar eliminación de OpenVPN? [y/N]: " remove
			done
			if test "$remove" =~ ^[yY]$; then
				port=$(grep '^port ' /etc/openvpn/server/server.conf | cut -d " " -f 2)
				protocol=$(grep '^proto ' /etc/openvpn/server/server.conf | cut -

d " " -f 2)
				if systemctl is-active --quiet firewalld.service; then
					ip=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s 10.8.0.0/24 '"'"'!'"'"' -d 10.8.0.0/24' | grep -oE '[^ ]+$')
					firewall-cmd --remove-port="$port"/"$protocol"
					firewall-cmd --zone=trusted --remove-source=10.8.0.0/24
					firewall-cmd --permanent --remove-port="$port"/"$protocol"
					firewall-cmd --permanent --zone=trusted --remove-source=10.8.0.0/24
					firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
					firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -s 10.8.0.0/24 ! -d 10.8.0.0/24 -j SNAT --to "$ip"
					if grep -qs "server-ipv6" /etc/openvpn/server/server.conf; then
						ip6=$(firewall-cmd --direct --get-rules ipv6 nat POSTROUTING | grep '\-s fddd:1194:1194:1194::/64 '"'"'!'"'"' -d fddd:1194:1194:1194::/64' | grep -oE '[^ ]+$')
						firewall-cmd --zone=trusted --remove-source=fddd:1194:1194:1194::/64
						firewall-cmd --permanent --zone=trusted --remove-source=fddd:1194:1194:1194::/64
						firewall-cmd --direct --remove-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
						firewall-cmd --permanent --direct --remove-rule ipv6 nat POSTROUTING 0 -s fddd:1194:1194:1194::/64 ! -d fddd:1194:1194:1194::/64 -j SNAT --to "$ip6"
					fi
				else
					systemctl disable --now openvpn-iptables.service
					rm -f /etc/systemd/system/openvpn-iptables.service
				fi
				if sestatus 2>/dev/null | grep "Current mode" | grep -q "enforcing" && test "$port" != 1194; then
					semanage port -d -t openvpn_port_t -p "$protocol" "$port"
				fi
				systemctl disable --now openvpn-server@server.service
				rm -rf /etc/openvpn/server
				rm -f /etc/systemd/system/openvpn-server@server.service.d/disable-limitnproc.conf
				rm -f /etc/sysctl.d/30-openvpn-forward.conf
				if test "$os" = "debian" || test "$os" = "ubuntu"; then
					apt-get remove --purge -y openvpn
				else
					yum remove -y openvpn
				fi
				echo
				echo "¡OpenVPN eliminado!"
			else
				echo
				echo "¡Eliminación de OpenVPN abortada!"
			fi
			exit
		;;
		4)
			exit
		;;
	esac
fi
```
