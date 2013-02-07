#!/bin/sh

dir=`dirname "${1}"`
mkdir -p "${dir}"

#берем снова 1-полный путь 2-файл
fdir="${1}"
filez="${2}"

# удаляем из полного пути имя файла, получаем директорию скачивания
target=${fdir%$filez}

touch "${target}""/.mjbignore"
