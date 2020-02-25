#!/bin/bash

# IMPORTANTE 
# Se debe crear un fichero pgpass en el directorio raiz del usuario que ejecuta este script
# con una linea por cada servidor con los datos de acceso que tendra
# servidor:puerto;base de datos:usuario:password
# Por ejemplo:
# localhost:5432:*:usuario:mypasswd
# Mas info -> https://www.postgresql.org/docs/12/libpq-pgpass.html

##############################
## POSTGRESQL CONFIGURACION ##
##############################
# Servidores a copiar separados por un espacio
SERVIDORES=(servidor1 192.168.1.3 192.168.2.5)

# Directorio donde se guardaran las copias de seguridad
DIR_COPIAS=/home/roke/backup/

# Dias que se almacenan las copias de seguridad
DIAS_A_GUARDAR=5

# Usuario que se utiliza para el volcado de las bases de datos
USUARIO=usuario

# Base de datos por defecto para conectar
BD_DEFECTO=db

for servidor in ${SERVIDORES[@]}; do
	FINAL_BACKUP_DIR=$DIR_COPIAS$servidor"/`date +\%Y-\%m-\%d`-copiasSQL/"

	echo "Creando directorio principal $FINAL_BACKUP_DIR"
	
	if ! mkdir -p $FINAL_BACKUP_DIR; then
		echo "No se puede crear el directorio $FINAL_BACKUP_DIR" 1>&2
		exit 1;
	fi;

	DATABASES=`psql -U $USUARIO -qAt -h $servidor -d $BD_DEFECTO -c "select datname from pg_database"`

	echo "Buscando bases de datos ..."
	# BASES DE DATOS
	for db in ${DATABASES[@]}; do
		if [[ "$db" != "template0" && "$db" != "template1" && "$db" != "postgres" ]]; then
			echo " - Creando directorio para base de datos $db -> $FINAL_BACKUP_DIR$db"
		
			if ! mkdir -p $FINAL_BACKUP_DIR$db; then
				echo "No se puede crear el directorio $FINAL_BACKUP_DIR" 1>&2
				exit 1;
			fi;

			# ESQUEMAS
			ESQUEMAS=`psql -U $USUARIO -qAt -h $servidor -d $db -c "select schema_name from information_schema.schemata"`
			for esquema in ${ESQUEMAS[@]}; do
				if [[ "$esquema" != "pg_catalog" && "$esquema" != "information_schema" ]]; then
					# TABLAS
					TABLAS=`psql -U $USUARIO -qAt -h $servidor -d $db -c "select tablename from pg_tables where schemaname='$esquema'"`
					echo " - Copiando tablas ..."
					for tabla in ${TABLAS[@]}; do
						echo "  . Copiando $tabla -> "$FINAL_BACKUP_DIR$db"/"$tabla".gz"
						pg_dump -U $USUARIO -h $servidor -d $db -C -t $tabla | gzip > $FINAL_BACKUP_DIR$db"/"$tabla.gz
					done;
				fi;
			done;
		fi;
	done;
done;

#################################
## BORRAR DIRECTORIOS ANTIGUOS ##
#################################

for servidor in ${SERVIDORES[@]}; do
	DIRECTORIO_COPIAS=$DIR_COPIAS$servidor
	find $DIRECTORIO_COPIAS -maxdepth 1 -mtime +$DIAS_A_GUARDAR -name "*-copiasSQL" -exec rm -rf '{}' ';'
done;
