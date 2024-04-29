#!/bin/bash
#Если условие в if истинно, выполняется код под ним
#Если условие в if не истинно
#но, истинно условие в elif, выполняется оно
#Если не одно из условий не истинно
#Выполняется else
if [ "$1" == "Vasya" ]; then
    echo "Привет, $1"
elif [ "$1" == "Trump" ]; then
    echo "Hello $1"
else
    echo "Greeting $1"
fi
#read - Записать ввод аргумента со стандартного ввода
#Опция -p означает print
#в конце то, куда записывается ввод, это x
#а x является началом case
read -p "Введите что-либо:" x

echo "Начало CASE..."
case $x in
        1) echo "Это число равняется 1";;
    [2-9]) echo "Число больше 1";;
  "Petya") echo "Hello $x";;
        *) echo "Аргумент не определен!"
esac
