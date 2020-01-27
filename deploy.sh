#!/bin/bash
MYSQL_HOST=$1
MYSQL_USER=$2
MYSQL_PASS=$3

SQL="CREATE DATABASE todo;
     USE todo;
     DROP TABLE IF EXISTS todo.tasks;
     CREATE TABLE IF NOT EXISTS todo.tasks
       (
           idTask TINYINT AUTO_INCREMENT,
           task VARCHAR(255) NOT NULL,
           status VARCHAR(255) NOT NULL,
           creation_date VARCHAR(30) NOT NULL,
           CONSTRAINT task_PK PRIMARY KEY (idTask)
        );"

## create table
mysql --host=$MYSQL_HOST --user=$MYSQL_USER --password=$MYSQL_PASS -e "$SQL"

##clone app repo
git clone https://github.com/mikonoid/todo-flask-app.git

cd todo-flask-app/

## prepare config.py
sed -i "s/root/${MYSQL_USER}/g" config.py

sed -i "s/password/${MYSQL_PASS}/g" config.py

sed -i "s/localhost/${MYSQL_HOST}/g" config.py

## pip install
sudo pip3 install flask mysql-connector flask_sqlalchemy

## run web server
nohup sudo  FLASK_APP="/home/ec2-user/todo-flask-app/app.py" FLASK_DEBUG=1 python3 -m flask run --host=0.0.0.0 --port=80 &
