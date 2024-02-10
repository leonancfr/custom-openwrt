#!/bin/bash

RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[32m'
NC='\033[0m' # No Color

VERSION=$(cat /etc/os-release | grep "^VERSION_ID" | cut -d'=' -f2 | tr -d '"')

echo -e "${BLUE}	   ____       _          _      _                        ${NC}"            
echo -e "${BLUE}	  / ___| __ _| |__  _ __(_) ___| |                       ${NC}"       
echo -e "${BLUE}	 | |  _ / _\` | '_ \| '__| |/ _ \ |                      ${NC}"   
echo -e "${BLUE}	 | |_| | (_| | |_) | |  | |  __/ |  ${GREEN}Version      ${NC}"     
echo -e "${BLUE}	  \____|\__,_|_.__/|_|  |_|\___|_|  ${GREEN} $VERSION    ${NC}"
echo -e "${RED}   ____ _                _ _       _      ___  ____           ${NC}"
echo -e "${RED}  / ___| |__   __ _ _ __| (_)_ __ | |__  / _ \/ ___|          ${NC}"
echo -e "${RED} | |   | '_ \ / _\` | '__| | | '_ \| '_ \| | | \___ \         ${NC}"
echo -e "${RED} | |___| | | | (_| | |  | | | | | | | | | |_| |___) |         ${NC}"
echo -e "${RED}  \____|_| |_|\__,_|_|  |_|_|_| |_|_| |_|\___/|____/          ${NC}"