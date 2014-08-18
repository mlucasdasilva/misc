#!/usr/bin/env python

import sys
import os, re

def help():
    print '''
    usage:
        ./dump.py from_database from_tablename to_tablename
'''

def sqlConvert(inSql):
    outSql = inSql;
    outSql = re.sub(r'''(`|unsigned )|CHARACTER SET utf8|((UN)?LOCK TABLES.*)|^--.*|\/\*[^\*]*\*\/;?''', '', outSql) 
    outSql = re.sub(r'smallint\(0\)', 'smallint', outSql)
    outSql = re.sub(r'unsigned', '', outSql)
    outSql = re.sub(r'on update current_timestamp', '', outSql)
    outSql = re.sub(r"\'", "''", outSql)
    outSql = re.sub(r"\_", "_", outSql)
    outSql = re.sub(r'\\', '', outSql)
    outSql = re.sub(r"%'", "%''", outSql)
    outSql = re.sub(r",\s*''", ",'", outSql)
    outSql = re.sub(r"'',", "',", outSql)
    outSql = re.sub(r"\(''", "('", outSql)
    outSql = re.sub(r"''\)", "')", outSql)
    outSql = re.sub(r'double', 'real', outSql)
    outSql = re.sub(r'datetime', 'timestamp', outSql)
    outSql = re.sub(r'int\([0-9]+\)', 'int', outSql)
    outSql = re.sub(r'^\s+KEY.*', '', outSql)
    outSql = re.sub(r' oid ', ' bigint ', outSql)
    outSql = re.sub(r'AUTO_INCREMENT(=.*)*', '', outSql)
    outSql = re.sub(r'UNIQUE KEY [^\(]*', 'UNIQUE', outSql)
    outSql = re.sub(r'order', '"order"', outSql)
    outSql = re.sub(r'tinyint', 'int', outSql)
    outSql = re.sub(r'COLLATE utf8_general_ci', '', outSql)
    #outSql = re.sub(r'\n\n', '\n', outSql)
    return outSql

if len(sys.argv) < 3:
    help()
else:
    fin  = os.popen('mysqldump -h192.168.6.2 -uroot -p123456 -K '+ sys.argv[1] + ' ' + sys.argv[2])
    fout = open(sys.argv[2] + '.sql', 'w')

    for eachLine in fin.readlines():
        sql = sqlConvert(eachLine)
        if(re.search('[^\s]+', sql)):
            #print sql,
            fout.write(sql)

    fin.close()
    fout.close()

    fExec = os.popen('../bin/psql ' + sys.argv[3].replace('clustrix', 'xcmgr') + ' -1 ' + ' -f ' + sys.argv[2] + '.sql')
    for eachLine in fExec.readlines():
        print eachLine
