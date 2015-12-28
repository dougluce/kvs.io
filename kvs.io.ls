#!env kvs.io.lsc
/* 

kvs.io -- a key-value store written in Livescript with listening
capabilities.

Written by Doug Luce <doug@kvsio-github.con.com>

*/

require! {
  path
  fs
}

main = path.join path.dirname(fs.realpathSync __filename), 'lib', 'api'

require main .standalone!
