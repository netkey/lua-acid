
import sys
import os

c = 'DROP TABLE `test`;'

cmd = 'echo \'%s\' | mysql test_db' % c
os.system(cmd)

c = '''CREATE TABLE `test` (
         `_id`  bigint NOT NULL AUTO_INCREMENT,
         `a_varchar` varchar(16),
         `b_text` text,
         `c_bigint` bigint,
         `d_tinyint` tinyint,
         PRIMARY KEY (`_id`)
         ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
'''


cmd = 'echo \'%s\' | mysql test_db' % c


os.system(cmd)
