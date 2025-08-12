#!/bin/bash

# ─────────────────────────────────────────────────────────────────────────────
# Este script instala PRISMA Framework en macOS, incluyendo la compilación de z88dk
# desde fuente y la configuración de dependencias necesarias. Verifica si la carpeta
# prisma existe, descomprime prisma.zip si está presente, o clona el repositorio desde
# GitHub. También configura variables de entorno y aplica correcciones comunes para
# compatibilidad con macOS (incluyendo ARM64).
#
# Copyright (c) 2025 Raul Carrillo (aka Metsuke) | Licensed under GNU GPL v3+
# More info: <http://www.gnu.org/licenses/>
# ─────────────────────────────────────────────────────────────────────────────

#GITHUB=https://github.com/cmgonzalez/prisma.git #Origen https
#GITHUB=https://github.com/metsuke/prisma-metsuos.git #metsuos-fork https
GITHUB=git@github.com:metsuke/prisma-metsuos.git #metsuos-fork ssh

# Script de instalación para PRISMA Framework en macOS
# Este script sigue las instrucciones del texto de README, incluyendo la compilación de z88dk desde fuente
# (ya que z88dk no está disponible directamente en Homebrew core).
# Se asume que estás usando zsh (predeterminado en macOS recientes), pero funciona con bash.
# Ejecuta este script con: bash install_prisma_mac.sh
# Nota: Requiere Homebrew instalado. Si no lo tienes, instala con: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

set -e  # Salir si hay un error

echo "🚀 Iniciando instalación de PRISMA Framework para macOS..."

# Obtener el directorio donde se encuentra el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paso 1: Instalar dependencias externas con Homebrew
echo "📦 Paso 1: Instalando dependencias con Homebrew (make, gcc, git, libpng)..."
brew install make gcc git libpng || true  # Ignorar si ya están instalados
brew link libpng || true  # Enlazar libpng para evitar errores con png.h

# Paso 2: Descargar y compilar z88dk desde fuente (versión 2.3 recomendada)
echo "🔧 Paso 2: Descargando y compilando z88dk desde fuente..."
cd ~
if [ ! -d "z88dk" ]; then
  wget https://master.dl.sourceforge.net/project/z88dk/v2.3/z88dk-src-2.3.tgz -O z88dk-src-2.3.tgz
  tar -xzf z88dk-src-2.3.tgz
  cd z88dk
  export BUILD_SDCC=1
  export BUILD_SDCC_HTTP=1
  chmod +x build.sh
  ./build.sh
  echo "✅ z88dk compilado exitosamente."
else
  echo "ℹ️ z88dk ya está presente en ~/z88dk, omitiendo compilación."
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
  } >> "$PROFILE_FILE"
  source "$PROFILE_FILE"
  echo "✅ Variables de entorno configuradas en $PROFILE_FILE."
else
  echo "ℹ️ Variables de entorno ya configuradas en $PROFILE_FILE."
fi

# Paso 4: Obtener el repositorio de PRISMA
echo "📂 Paso 4: Obteniendo el repositorio de PRISMA..."
cd "$SCRIPT_DIR"
if [ -d "prisma" ]; then
  echo "✅ Carpeta prisma ya existe en $SCRIPT_DIR/prisma, omitiendo clonación/descompresión."
elif [ -f "prisma.zip" ]; then
  echo "📦 Encontrado prisma.zip, descomprimiendo..."
  unzip -q prisma.zip -d prisma
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

[ -d prisma-metsuos ] && mv prisma-metsuos prisma && echo "Carpeta renombrada a prisma." || echo "Carpeta prisma-metsuos no existe."
cd prisma

# Paso 5: Crear carpeta build si no existe (para evitar errores en ARM64)
echo "🛠️ Paso 5: Creando carpeta build si no existe..."
mkdir -p build
echo "✅ Carpeta build creada."

# Paso 6: Compilar las herramientas del framework
echo "🔨 Paso 6: Compilando las herramientas de PRISMA con 'make tools'..."
make tools
echo "✅ Herramientas compiladas."

# Paso 7: Fix para error común en z88dk (renombrar zsdcpp si existe)
echo "🛡️ Paso 7: Aplicando fix para posible error 'zsdcpp: command not found'..."
if [ -f "$HOME/z88dk/bin/zdcpp" ]; then
  mv "$HOME/z88dk/bin/zdcpp" "$HOME/z88dk/bin/zsdcpp"
  echo "✅ Ejecutable renombrado a zsdcpp."
else
  echo "ℹ️ No se encontró zdcpp, no es necesario renombrar."
fi

echo "🎉 Instalación completada exitosamente!"
echo "Para probar: cd $SCRIPT_DIR/prisma && make help"
echo "Si hay errores, verifica las notas para ARM64 en la documentación (ej. libpng ya está instalado)."