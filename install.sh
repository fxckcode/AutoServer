#!/bin/bash

# Verificar si el usuario es root
# if [ "$EUID" -ne 0 ]; then
#   echo "Este script debe ser ejecutado como root" >&2
#   exit 1
# fi

logo() {
  echo "

 █████╗ ██╗   ██╗████████╗ ██████╗     ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗ 
██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
███████║██║   ██║   ██║   ██║   ██║    ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
██╔══██║██║   ██║   ██║   ██║   ██║    ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
                                                                                        

"
}

# Función para instalar dependencias
# install_dependencies() {
#   apt update -y && apt upgrade -y
#   apt install -y curl

#   # Instalar NVM y Node.js para todos los usuarios
#   su - $SUDO_USER -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash'
#   su - $SUDO_USER -c 'source ~/.nvm/nvm.sh && nvm install node'
  
#   # Instalar pm2 globalmente para todos los usuarios
#   su - $SUDO_USER -c 'npm install -g pm2'

#   # Instalar otras dependencias como root
#   apt install -y git wget nginx mysql-server net-tools openvswitch-switch phpmyadmin php8.1-fpm php-mysql 

#   clear

#   echo "Instalación hecha con exito, por favor reiniciar"
#   read -p "Presione Enter para volver al menú principal..."
# }

install_dependencies() {
  sudo apt update -y && sudo apt upgrade -y
  sudo apt install -y curl

  # Instalar NVM y Node.js para todos los usuarios
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
  source ~/.nvm/nvm.sh && nvm install node
  
  # Instalar pm2 globalmente para todos los usuarios
  npm install -g pm2

  # Instalar otras dependencias como root
  sudo apt install -y git wget nginx mysql-server net-tools openvswitch-switch phpmyadmin php8.1-fpm php-mysql 

  clear

  logo

  echo "Instalación hecha con exito, por favor reiniciar"
  read -p "Presione Enter para volver al menú principal..."
}

# Función para la configuración básica
configuration() {
  clear
  echo "Configuración básica de los elementos"

  sudo ufw allow 'Nginx Full'
  sudo ufw allow 'Nginx HTTP'
  sudo ufw allow 'Nginx HTTPS'
  sudo ufw allow 'OpenSSH'

  sudo ufw enable
  sudo ufw status

  # Eliminar archivo default de nginx
  if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
    echo "Archivo default de Nginx eliminado."
  fi

  sudo ln -s /usr/share/phpmyadmin/ /var/www/html/phpmyadmin

  # Copiar nuevo archivo de configuración
  sudo cp ./default /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

  # Probar la configuración de Nginx y reiniciar el servicio
  sudo nginx -t && sudo systemctl reload nginx

  clear

  logo

  echo "Configuración de Nginx actualizada y servicio reiniciado."

  read -p "Cuál es el nombre de usuario nuevo para Mysql:  " user
  read -p "Cual es la contraseña para ese usuario:  " password

  # Configurar nuevo usuario en MySQL
  sudo mysql -u root -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password';"
  sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '$user'@'localhost' WITH GRANT OPTION;"
  sudo mysql -u root -e "FLUSH PRIVILEGES;"

  echo "Usuario '$user' configurado en MySQL."

  clear

  logo

  read -p "Presione Enter para volver al menú principal..."
}

# Función para el despliegue
deployment() {
  clear

  logo

  echo "Configuración de la IP estática"

  read -p "Nueva IP estática: " ip_static
  read -p "Categoría de la IP (CIDR, ej. 24): " category
  read -p "Puerta de enlace predeterminada: " gateway 

  read_netplan "$ip_static" "$category" "$gateway"

  mkdir -p backup

  sudo cp /etc/netplan/00-installer-config.yaml ./backup/

  sudo rm -r /etc/netplan/00-installer-config.yaml
  sudo cp ./netplan/00-installer-config.yaml /etc/netplan/
  sudo netplan apply

  clear

  logo

  read -p "Configuración aplicada, presione Enter para continuar..."

  clear

  logo

  echo "Montaje de los proyectos"

  read -p "Ruta absoluta del backend: " backend
  read -p "Ruta absoluta del frontend: " frontend

  install_projects "$backend" "$frontend"

  clear

  logo

  echo
  read -p "Presione Enter para volver al menú principal..."
}

# Función para leer y generar el archivo de configuración de netplan
read_netplan() {
  local ip_static=$1
  local category=$2
  local gateway=$3

  mkdir -p netplan  # -p crea el directorio solo si no existe

  cat <<EOL > ./netplan/00-installer-config.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    enp0s3:
      dhcp4: no
      addresses: [$ip_static/$category]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
      routes:
        - to: default
          via: $gateway
  version: 2
EOL

  echo "Configuración generada con éxito"
  echo 
  echo "Resumen: "
  echo "  IP: $ip_static"
  echo "  Categoria (CIDR): $category"
  echo "  Puerta de enlace: $gateway"
  echo
}

install_projects() {
  local backend=$1
  local frontend=$2

  if [ -d "$backend" -a -d "$frontend" ]; then
    if [ -d "$backend/node_modules" ]; then
      sudo rm -r "$backend/node_modules"
    fi

    if [ -d "$frontend/node_modules" ]; then
      sudo rm -r "$frontend/node_modules"
    fi

    cd "$backend"
    npm install

    clear

    logo

    read -p "Con que comando arranca el backend [npm run ...]: " run_backend
    read -p "En que puerto corre el backend (Ej. 3000): " port_backend

    sudo ufw allow "$port_backend/tcp"
    sudo ufw allow "$port_backend"

    pm2 delete "backend"
    pm2 start npm --name "backend" -- run "$run_backend"

    cd "$frontend"
    npm install

    read -p "Con que comando arranca el frontend [npm run ...]: " run_frontend
    read -p "En que puerto corre el frontend (Ej. 3000): " port_frontend 

    sudo ufw allow "$port_frontend/tcp"
    sudo ufw allow "$port_frontend"

    pm2 delete "frontend"
    pm2 start npm --name "frontend" -- run "$run_frontend"

    clear

    logo 
    
    pm2 list
    
    pm2 save

    read -p "Operación correctamente realizada"

  else
    echo "Directorios invalido"
  fi
}

reboot() {
  echo "Reiniciando..."
  sudo reboot
}

# Bucle del menú principal
while true; do
  clear
  logo
  echo "1 - Instalar las dependencias"
  echo "2 - Configuración básica de los elementos"
  echo "3 - Despliegue"
  echo "4 - Reinicar servidor"
  echo "5 - Salir"

  read -p "Seleccione una opción: " option

  case $option in
    1)
      install_dependencies
      ;;
    2)
      configuration
      ;;
    3)
      deployment
      ;;
    4)
      reboot
      ;;
    5)
      echo "Saliendo del script..."
      exit 0
      ;;
    *)
      echo "Opción no válida. Por favor, seleccione 1, 2, 3, 4 o 5"
      read -p "Presione Enter para volver al menú principal..."
      ;;
  esac
done
