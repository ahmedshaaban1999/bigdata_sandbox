#!/bin/bash

#Script to download and configure hadoop components
#Supported components:
#1. Hdfs
#2. Hive
#3. Spark
#4. Kafka
#5. Zookeeper

#Part 0: check for pre-requistes
  if [ `whoami` = root ]
  then 
    echo "Please run this script without using sudo"
    exit
  fi
 if ! systemctl status sshd | grep running &> /dev/null
 then
   echo "sshd service is not running. Starting the service"
   sudo systemctl enable sshd
   sudo systemctl start sshd
 fi

#Part 1: create root directory
 scriptPath=`pwd`
 echo "Enter the root directory in which all the components will be installed"
 read rootPath
 [ ! -d $rootPath ] && echo "Directory $rootPath does not exists. Creating the directory" && mkdir $rootPath

#Part 2: downloading the sources
 mkdir $rootPath/sources
 cd $rootPath/sources
# wget https://downloads.apache.org/hadoop/common/hadoop-3.1.3/hadoop-3.1.3.tar.gz
# wget https://downloads.apache.org/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz
# wget https://archive.apache.org/dist/spark/spark-3.0.0/spark-3.0.0-bin-hadoop2.7.tgz
# wget https://downloads.apache.org/kafka/2.6.0/kafka_2.12-2.6.0.tgz
# wget https://downloads.apache.org/zookeeper/zookeeper-3.6.2/apache-zookeeper-3.6.2-bin.tar.gz

#Part 3: extracting the archives
 for source in ./*; do
     tar -C $rootPath -zxvf $source
 done

#Part 4: install python 3.6 and java 1.8
#For jre
 if ! command -v java &> /dev/null
 then
     echo "java runtime kit not found. Installing jre 1.8.0 ..."
     sudo yum install -y java-1.8.0-openjdk
 else
     javaVersion=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -c 1-3)
     if [ $javaVersion != '1.8' ]
     then
         echo "jre version is not 1.8. Installing version 1.8.0 ..."
         sudo yum install -y java-1.8.0-openjdk
     fi
 fi

#For jdk
 if ! command -v javac &> /dev/null
 then
     echo "java development kit not found. Installing jdk 1.8.0 ..."
     sudo yum install -y java-1.8.0-openjdk-devel.x86_64
 else
     javacVersion=$(javac -version 2>&1 | cut -c 7-9)
     if [ $javacVersion != '1.8' ]
     then
         echo "jdk version is not 1.8. Installing version 1.8.0 ..."
         sudo yum install -y java-1.8.0-openjdk-devel.x86_64
     fi
 fi

#For python
 if ( ! command -v python3.6 &> /dev/null ) && ( ! command -v python3 &> /dev/null )
 then
     echo "python is not installed. Installing python3.6 ..."
     sudo yum install -y https://repo.ius.io/ius-release-el7.rpm
     sudo yum update -y
     sudo yum install -y python36u python36u-libs python36u-devel python36u-pip
 else
     pythonVersion=`python3 --version | cut -c 8-10`
     if [ $pythonVersion != '3.6' ]
     then 
         echo "python version is not 3.6. Installing version 3.6 ..."
         sudo yum install -y https://repo.ius.io/ius-release-el7.rpm
         sudo yum update -y
         sudo yum install -y python36u python36u-libs python36u-devel python36u-pip
     fi
 fi

#Part 5: write into .bash_profile
 echo "export ROOT_PATH=$rootPath" >> ~/.bash_profile
 #javaPath=`ls /usr/lib/jvm | grep java-1.8`
 echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0/jre" >> ~/.bash_profile
 echo "export PYSPARK_PYTHON=python36" >> ~/.bash_profile
 hive=`ls $rootPath | grep hive`
 echo "export HIVE_HOME=$rootPath/$hive" >> ~/.bash_profile
 hadoop=`ls $rootPath | grep hadoop-3.1`
 echo "export HADOOP_HOME=$rootPath/$hadoop" >> ~/.bash_profile
 kafka=`ls $rootPath | grep kafka`
 echo "export KAFKA_HOME=$rootPath/$kafka" >> ~/.bash_profile
 spark=`ls $rootPath | grep spark`
 echo "export SPARK_HOME=$rootPath/$spark" >> ~/.bash_profile
 zookeeper=`ls $rootPath | grep zookeeper`
 echo "export ZOOKEEPER_HOME=$rootPath/$zookeeper" >> ~/.bash_profile
 echo "PATH=\$PATH:\$HADOOP_HOME/bin:\$HIVE_HOME/bin:\$KAFKA_HOME/bin:\$ZOOKEEPER_HOME\bin" >> ~/.bash_profile
 echo "export PATH" >> ~/.bash_profile
 source ~/.bash_profile

#Part 6: create and/or replace documents
 cd $scriptPath
 yes | cp -rf core-site.xml mapred-site.xml hdfs-site.xml yarn-site.xml $rootPath/hadoop-3.1.3/etc/hadoop
 yes | cp -rf hive-site.xml $rootPath/apache-hive-3.1.2-bin/conf
 yes | cp -rf hive-site.xml $rootPath/spark-3.0.0-bin-hadoop2.7/conf
 echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0/jre" >> $rootPath/hadoop-3.1.3/etc/hadoop/hadoop-env.sh
 echo "export ROOT_PATH="$rootPath"" >> $rootPath/hadoop-3.1.3/etc/hadoop/hadoop-env.sh

#Part 7: generate ssh keys
 ssh-keygen -t rsa -P '' -y -f ~/.ssh/id_rsa
 cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
 chmod 600 ~/.ssh/authorized_keys

#Part 8: replace jars
 rm -f $SPARK_HOME/jars/derby-10.12.1.1.jar
 yes | cp -rf $HIVE_HOME/lib/derby-10.14.1.0.jar $SPARK_HOME/jars/
 rm -f $HIVE_HOME/lib/guava-19.0.jar
 yes | cp -rf $HADOOP_HOME/share/hadoop/hdfs/lib/guava-27.0-jre.jar $HIVE_HOME/lib/

#Part 9: specific commands
 hdfs namenode -format
 $HADOOP_HOME/sbin/start-all.sh
 hdfs dfs -mkdir /tmp
 hdfs dfs -mkdir /user
 hdfs dfs -mkdir /user/hive
 hdfs dfs -mkdir /user/hive/warehouse
 hdfs dfs -chmod g+w /tmp
 hdfs dfs -chmod g+w /user/hive/warehouse
