#!/bin/bash

# 1. 변수 설정 (172.16.0.16은 seongwon npm의 주소)
PROXY_IP="172.16.0.16"
ZABBIX_VERSION="7.0"
UBUNTU_VER=$(lsb_release -rs)

echo "--- Zabbix Agent 2 설치 시작 (OS Version: $UBUNTU_VER) ---"

# 2. 리포지토리 등록 및 에이전트 설치
wget -q -O /tmp/zabbix-release.deb https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu${UBUNTU_VER}_all.deb
sudo dpkg -i /tmp/zabbix-release.deb
sudo apt update
sudo apt install zabbix-agent2 zabbix-agent2-plugin-* -y

# 3. awk를 이용한 zabbix_agent2.conf 수정
CONF_FILE="/etc/zabbix/zabbix_agent2.conf"

if [ -f "$CONF_FILE" ]; then
    sudo awk -v proxy="$PROXY_IP" '
    # Server 설정: 127.0.0.1과 프록시 IP 허용(nangman 팀에서는 active모드로 에이전트가 zabbix-proxy로 보내서 zabbix-proxy가 zabbix-server로 보낼거라 큰 의미 없음)
    /^Server=127.0.0.1/ { print "Server=127.0.0.1," proxy; next }
    
    # ServerActive 설정: 데이터를 보낼 프록시 지정
    /^ServerActive=127.0.0.1/ { print "ServerActive=" proxy; next }
    
    # Hostname 설정: 기존 정적 이름 주석 처리
    /^Hostname=/ { print "# " $0; next }
    
    # HostnameItem 설정: 시스템 호스트네임 자동 인식 활성화
    /^# HostnameItem=system.hostname/ { print "HostnameItem=system.hostname"; next }
    
    # 나머지는 그대로 출력
    { print }
    ' $CONF_FILE > ${CONF_FILE}.tmp && sudo mv ${CONF_FILE}.tmp $CONF_FILE

    # 4. 서비스 재시작 및 등록
    sudo systemctl enable zabbix-agent2
    sudo systemctl restart zabbix-agent2
    echo "--- 설정 완료: [$(hostname)] ---"
else
    echo "오류: 설정 파일을 찾을 수 없습니다."
    exit 1
fi