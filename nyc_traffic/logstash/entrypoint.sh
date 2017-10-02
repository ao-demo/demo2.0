#!/bin/sh

#set -e

echo "Present Working Directory " $(pwd)
echo "Logstash Home Directory " ${LOGSTASH_HOME}
echo "Instruction Set URL " ${INSTR_URL}

# Added on 10/02
# Start------------------------
echo "Exit Flag Value " ${EXIT_FLAG}

if [ -n "${EXIT_FLAG}" ];
then
        echo "Exit Flag is Set";
        exit;
else
        echo "Exit Flag is Not Set";
fi;
# End------------------------

JSON_FILE="https://raw.githubusercontent.com/ao-demo/demo2.0/master/nyc_traffic/InstructionSet.json"
# ENV variable {INSTR_URL}


#INSTR_URL is being passed as an ENV variable from the application blueprint
if [ -n "$INSTR_URL" ] ; then JSON_FILE=${INSTR_URL}; fi 

for i in "$@"
do
	case $i in
		-instr=*|--instruction-set=*)
			JSON_FILE="${i#*=}"
			shift
			;;
		-conf=*|--logstash-conf=*)
			LOGSTASH_FILE="${i#*=}"
			shift
			;;
	esac
done

# Change to WORKPATH
cd ${WORKPATH}

wget ${JSON_FILE} -O elk_demo2.0.json #renamed to elk_demo2.0.json as elkinitializer uses this name as the metafile
./elkinitializer 

# No error checking!!!. Need to improve script for the next iteration.
# Inject Dataset into Elasticsearch
cat dataset.csv | ${LOGSTASH_HOME}/bin/logstash -f logstash.conf
tail -f dummylogfile
