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
# - Soporte para --refresh: reinstala dependencias y renombra carpeta prisma a prisma_old.
# - Mensajes mejorados para trazabilidad en commits de GitHub.
# - Corrección de formato en mensajes: añadido espacio entre iconos y texto.
# - Revisión adicional para garantizar formato consistente en todos los mensajes.
# ─────────────────────────────────────────────────────────────────────────────

#GITHUB=https://github.com/cmgonzalez/prisma.git #Origen https
#GITHUB=https://github.com/metsuke/prisma-metsuos.git #metsuos-fork https
GITHUB=git@github.com:metsuke/prisma-metsuos.git #metsuos-fork ssh

set -e  # Salir si hay un error

# Verificar si se pasó el parámetro --refresh
REFRESH=false
if [ "$1" = "--refresh" ]; then
  REFRESH=true
  echo "🔄 Modo --refresh activado: se reinstalarán dependencias y se renombrará la carpeta prisma si existe."
fi

echo "🚀 Iniciando instalación de PRISMA Framework para macOS..."

# Obtener el directorio donde se encuentra el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Función para verificar si un comando está instalado
check_installed() {
  command -v "$1" >/dev/null 2>&1
}

# Paso 1: Instalar dependencias externas con Homebrew
echo "📦 Paso 1: Verificando e instalando dependencias con Homebrew (make, gcc, git, libpng)..."
for pkg in make gcc git libpng; do
  if check_installed "$pkg" && [ "$REFRESH" = false ]; then
    echo "ℹ️  $pkg ya está instalado, omitiendo instalación."
  else
    echo "📥 Instalando $pkg..."
    brew install "$pkg" || { echo "❌ Error al instalar $pkg."; exit 1; }
    [ "$pkg" = "libpng" ] && brew link libpng || true
    echo "✅ $pkg instalado exitosamente."
  fi
done

# Paso 2: Descargar y compilar z88dk desde fuente
echo "🔧 Paso 2: Verificando y compilando z88dk desde fuente..."
cd ~
if [ -d "z88dk" ] && [ "$REFRESH" = false ]; then
  echo "ℹ️  z88dk ya está presente en ~/z88dk, omitiendo compilación."
else
  if [ -d "z88dk" ] && [ "$REFRESH" = true ]; then
    echo "🔄 Renombrando z88dk a z88dk_old debido a --refresh..."
    mv z88dk z88dk_old || { echo "❌ Error al renombrar z88dk."; exit 1; }
  fi
  echo "📥 Descargando z88dk-src-2.3..."
  wget https://master.dl.sourceforge.net/project/z88dk/v2.3/z88dk-src-2.3.tgz -O z88dk-src-2.3.tgz || {
    echo "❌ Error al descargar z88dk."; exit 1; }
  tar -xzf z88dk-src-2.3.tgz
  cd z88dk
  export BUILD_SDCC=1
  export BUILD_SDCC_HTTP=1
  chmod +x build.sh
  ./build.sh || { echo "❌ Error al compilar z88dk."; exit 1; }
  echo "✅ z88dk compilado exitosamente."
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
  echo "ℹ️  Variables de entorno ya configuradas en $PROFILE_FILE."
fi

# Paso 4: Obtener el repositorio de PRISMA
echo "📂 Paso 4: Obteniendo el repositorio de PRISMA..."
cd "$SCRIPT_DIR"
if [ -d "prisma" ] && [ "$REFRESH" = false ]; then
  echo "ℹ️  Carpeta prisma ya existe en $SCRIPT_DIR/prisma, omitiendo clonación/descompresión."
else
  if [ -d "prisma" ] && [ "$REFRESH" = true ]; then
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

# Paso SIX: Compilar las herramientas del framework
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