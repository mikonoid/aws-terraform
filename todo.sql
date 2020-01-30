CREATE DATABASE IF NOT EXISTS todo;
     USE todo;
     DROP TABLE IF EXISTS todo.tasks;
     CREATE TABLE IF NOT EXISTS todo.tasks
       (
           idTask TINYINT AUTO_INCREMENT,
           task VARCHAR(255) NOT NULL,
           status VARCHAR(255) NOT NULL,
           creation_date VARCHAR(30) NOT NULL,
           CONSTRAINT task_PK PRIMARY KEY (idTask)
        );
