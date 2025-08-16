#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Este script instala PRISMA Framework en macOS, incluyendo la compilación de z88dk
# desde fuente y la configuración de dependencias necesarias. Verifica si las
# dependencias están instaladas y omite su instalación a menos que se pase el
# parámetro --refresh. Si la carpeta prisma existe, no se clona ni descomprime de
# nuevo, salvo con --refresh, en cuyo caso se renombra a prisma_old. Las acciones
# realizadas se documentan para un commit claro en GitHub.
#
# Uso: bash install_prisma_mac.sh [--refresh]
#
# Copyright (c) 2025 Raul Carrillo (aka Metsuke) | Licensed under GNU GPL v3+
# More info: <http://www.gnu.org/licenses/>
#
# Cambios realizados:
# - Verificación de dependencias instaladas antes de instalar con Homebrew.
# - Soporte para --refresh: reinstala dependencias y renombra carpetas prisma y z88dk.
# - Mensajes mejorados para trazabilidad en commits de GitHub.
# - Corrección de formato en mensajes: añadido espacio entre iconos y texto.
# - Añadida impresión de la variable PATH activa para depuración.
# - Corrección de error tipográfico en comentario (Paso SIX → Paso 6).
# - Añadida instalación y configuración de Boost para resolver error de compilación de z88dk.
# - Corrección para renombrar z88dk: elimina z88dk_old si existe con --refresh.
# - Añadidas variables CFLAGS, CXXFLAGS, LDFLAGS para Boost en ARM64/Intel.
# - Verificación explícita de boost/graph/adjacency_list.hpp antes de compilar z88dk.
# - Ajustes en descarga de z88dk y su compilación recursiva
# ─────────────────────────────────────────────────────────────────────────────

#GITHUB=https://github.com/cmgonzalez/prisma.git #Origen https
#GITHUB=https://github.com/metsuke/prisma-metsuos.git #metsuos-fork https
GITHUB=git@github.com:metsuke/prisma-metsuos.git #metsuos-fork ssh

set -e  # Salir si hay un error

# Verificar si se pasó el parámetro --refresh
REFRESH=false
if [ "$1" = "--refresh" ]; then
  REFRESH=true
  echo "🔄 Modo --refresh activado: se reinstalarán dependencias y se renombrarán las carpetas prisma y z88dk si existen."
fi

echo "🚀 Iniciando instalación de PRISMA Framework para macOS..."

# Obtener el directorio donde se encuentra el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Imprimir la variable de entorno PATH activa
echo "📍 Variable de entorno PATH activa: $PATH"

# Función para verificar si un comando está instalado
check_installed() {
  command -v "$1" >/dev/null 2>&1
}

# Función para verificar si Boost está instalado y tiene el archivo necesario
check_boost_installed() {
  if [ "$(uname -m)" = "arm64" ]; then
    [ -f "/opt/homebrew/include/boost/graph/adjacency_list.hpp" ]
  else
    [ -f "/usr/local/include/boost/graph/adjacency_list.hpp" ]
  fi
}

# Determinar la ruta de Boost según la arquitectura
if [ "$(uname -m)" = "arm64" ]; then
  BOOST_ROOT="/opt/homebrew"
  BOOST_INCLUDE="/opt/homebrew/include"
  BOOST_LIB="/opt/homebrew/lib"
else
  BOOST_ROOT="/usr/local"
  BOOST_INCLUDE="/usr/local/include"
  BOOST_LIB="/usr/local/lib"
fi

# Paso 1: Instalar dependencias externas con Homebrew
echo "📦 Paso 1: Verificando e instalando dependencias con Homebrew (make, gcc, git, libpng, boost)..."
for pkg in make gcc git libpng boost; do
  if check_installed "$pkg" && [ "$pkg" != "boost" ] && [ "$REFRESH" = false ]; then
    echo "ℹ️  $pkg ya está instalado, omitiendo instalación."
  elif [ "$pkg" = "boost" ] && check_boost_installed && [ "$REFRESH" = false ]; then
    echo "ℹ️  boost ya está instalado en $BOOST_ROOT, omitiendo instalación."
  else
    echo "📥 Instalando $pkg..."
    brew install "$pkg" || { echo "❌ Error al instalar $pkg."; exit 1; }
    [ "$pkg" = "libpng" ] && brew link libpng || true
    echo "✅ $pkg instalado exitosamente."
  fi
done

# Verificar explícitamente la presencia de boost/graph/adjacency_list.hpp
echo "🔍 Verificando la presencia de boost/graph/adjacency_list.hpp..."
if ! check_boost_installed; then
  echo "❌ Error: boost/graph/adjacency_list.hpp no encontrado en $BOOST_INCLUDE."
  echo "💡 Intenta reinstalar Boost con: brew reinstall boost"
  exit 1
fi
echo "✅ boost/graph/adjacency_list.hpp encontrado en $BOOST_INCLUDE "

# Paso 2: Clonar y compilar z88dk desde GitHub
echo "🔧 Paso 2: Verificando y compilando z88dk desde GitHub..."
cd ~
if [ -d "z88dk" ] && [ "$REFRESH" = false ]; then
  echo "ℹ️ z88dk ya está presente en ~/z88dk, omitiendo clonación y compilación."
else
  if [ -d "z88dk" ] && [ "$REFRESH" = true ]; then
    if [ -d "z88dk_old" ]; then
      echo "🗑️ Eliminando z88dk_old existente debido a --refresh..."
      rm -rf z88dk_old || { echo "❌ Error al eliminar z88dk_old."; exit 1; }
    fi
    echo "🔄 Renombrando z88dk a z88dk_old debido a --refresh..."
    mv z88dk z88dk_old || { echo "❌ Error al renombrar z88dk."; exit 1; }
  fi
  echo "📥 Clonando el repositorio de z88dk desde GitHub..."
  git clone --recursive https://github.com/metsuke/z88dk-metsuos.git || {
    echo "❌ Error al clonar el repositorio de z88dk. Verifica tu conexión o permisos."
    exit 1
  }
  mv z88dk-metsuos z88dk
  cd z88dk
  export BUILD_SDCC=1
  export BUILD_SDCC_HTTP=1
  export BOOST_ROOT="$BOOST_ROOT"
  export CFLAGS="-I$BOOST_INCLUDE"
  export CXXFLAGS="-I$BOOST_INCLUDE"
  export LDFLAGS="-L$BOOST_LIB"
  chmod +x build.sh
  ./build.sh || { echo "❌ Error al compilar z88dk. Verifica el archivo config.log para más detalles."; exit 1; }
  echo "✅ z88dk clonado y compilado exitosamente."
fi

# Paso 3: Configurar variables de entorno para z88dk y PRISMA
echo "⚙️ Paso 3: Configurando variables de entorno..."
PROFILE_FILE="$HOME/.zshrc"  # Usa .zshrc por defecto en macOS; cambia a .bash_profile si usas bash
if ! grep -q "Z88DK" "$PROFILE_FILE"; then
  {
    echo ""
    echo "# Variables para z88dk y PRISMA Framework"
    echo "export Z88DK=\$HOME/z88dk"
    echo "export Z88DK_PATH=\$HOME/z88dk"
    echo "export PATH=\$Z88DK/bin:\$PATH"
    echo "export Z80_OZFILES=\$Z88DK/lib"
    echo "export ZCCCFG=\$Z88DK/lib/config"
    echo "export BOOST_ROOT=$BOOST_ROOT"
    echo "export CFLAGS=\"-I$BOOST_INCLUDE \$CFLAGS\""
    echo "export CXXFLAGS=\"-I$BOOST_INCLUDE \$CXXFLAGS\""
    echo "export LDFLAGS=\"-L$BOOST_LIB \$LDFLAGS\""
  } >> "$PROFILE_FILE"
  source "$PROFILE_FILE"
  echo "✅ Variables de entorno configuradas en $PROFILE_FILE."
else
  echo "ℹ️  Variables de entorno ya configuradas en $PROFILE_FILE."
fi

# Paso 4: Obtener el repositorio de PRISMA
echo "📂 Paso 4: Obteniendo el repositorio de PRISMA..."
cd "$SCRIPT_DIR"
if [ -d "prisma" ] && [ "$REFRESH" = false ]; then
  echo "ℹ️  Carpeta prisma ya existe en $SCRIPT_DIR/prisma, omitiendo clonación/descompresión."
else
  if [ -d "prisma" ] && [ "$REFRESH" = true ]; then
    if [ -d "prisma_old" ]; then
      echo "🗑️  Eliminando prisma_old existente debido a --refresh..."
      rm -rf prisma_old || { echo "❌ Error al eliminar prisma_old."; exit 1; }
    fi
    echo "🔄 Renombrando prisma a prisma_old debido a --refresh..."
    mv prisma prisma_old || { echo "❌ Error al renombrar prisma."; exit 1; }
  fi
  if [ -f "prisma.zip" ]; then
    echo "📦 Encontrado prisma.zip, descomprimiendo..."
    unzip -q prisma.zip -d prisma || { echo "❌ Error al descomprimir prisma.zip."; exit 1; }
    echo "✅ prisma.zip descomprimido en $SCRIPT_DIR/prisma."
  else
    echo "📥 Clonando el repositorio de PRISMA desde GitHub..."
    git clone $GITHUB || {
      echo "❌ Error al clonar el repositorio. Verifica tus credenciales de GitHub."
      echo "💡 Usa un token de acceso personal (PAT) o configura SSH. Instrucciones:"
      echo "  1. Genera un PAT en https://github.com/settings/tokens (con permisos 'repo')."
      echo "  2. Usa el PAT como contraseña al clonar."
      echo "  3. O configura SSH: ssh-keygen -t rsa -b 4096, luego agrega la clave pública a GitHub."
      exit 1
    }
    echo "✅ Repositorio clonado en $SCRIPT_DIR/prisma."
  fi
fi

[ -d prisma-metsuos ] && mv prisma-metsuos prisma && echo "✅ Carpeta renombrada a prisma." || echo "ℹ️  Carpeta prisma-metsuos no existe."
cd prisma

# Paso 5: Crear carpeta build si no existe
echo "🛠️ Paso 5: Creando carpeta build si no existe..."
mkdir -p build
echo "✅ Carpeta build creada."

# Paso 6: Compilar las herramientas del framework
echo "🔨 Paso 6: Compilando las herramientas de PRISMA con 'make tools'..."
make tools || { echo "❌ Error al compilar herramientas."; exit 1; }
echo "✅ Herramientas compiladas."

# Paso 7: Fix para error común en z88dk
echo "🛡️ Paso 7: Aplicando fix para posible error 'zsdcpp: command not found'..."
if [ -f "$HOME/z88dk/bin/zdcpp" ]; then
  mv "$HOME/z88dk/bin/zdcpp" "$HOME/z88dk/bin/zsdcpp"
  echo "✅ Ejecutable renombrado a zsdcpp."
else
  echo "ℹ️  No se encontró zdcpp, no es necesario renombrar."
fi

echo "🎉 Instalación completada exitosamente!"
echo "Para probar: cd $SCRIPT_DIR/prisma && make help"
echo "Si hay errores, verifica las notas para ARM64 en la documentación (ej. libpng ya está instalado)."