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
# deployment() {
#   clear
#   echo "Despliegue de los elementos"
#   read -p "Presione Enter para volver al menú principal..."
# }

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
  echo "3 - Reinicar servidor"
  echo "4 - Salir"

  read -p "Seleccione una opción: " option

  case $option in
    1)
      install_dependencies
      ;;
    2)
      configuration
      ;;
    3)
      reboot
      ;;
    4)
      echo "Saliendo del script..."
      exit 0
      ;;
    *)
      echo "Opción no válida. Por favor, seleccione 1, 2, 3, 4 o 5"
      read -p "Presione Enter para volver al menú principal..."
      ;;
  esac
done
